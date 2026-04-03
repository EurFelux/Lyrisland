import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandPanel: DynamicIslandPanel?
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let spotifyService = SpotifyAppleScriptService()
    private let lyricsManager = LyricsManager()
    private let syncEngine = PlaybackSyncEngine()
    private let appState = AppState()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        Log.shared.cleanupOldLogs()
        logInfo("Lyrisland launched")

        setupMenuBar()

        if appState.hasCompletedOnboarding {
            launchMainUI()
        } else {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_: Notification) {
        logInfo("Lyrisland terminating")
        Log.shared.flush()
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        appState.refresh()

        let onboardingView = OnboardingView(appState: appState) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.launchMainUI()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = String(localized: "menu.welcome")
        window.contentView = NSHostingView(rootView: onboardingView)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(white: 0.1, alpha: 1)
        window.makeKeyAndOrderFront(nil)

        // Bring app to front for onboarding
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }

    private func launchMainUI() {
        syncEngine.lyricsManager = lyricsManager
        setupIslandPanel()
        startPlaybackMonitoring()
    }

    // MARK: - Menu Bar

    private var trackMenuItem: NSMenuItem?
    private var sourceMenuItem: NSMenuItem?
    private var dualLineMenuItem: NSMenuItem?
    private var showArtworkMenuItem: NSMenuItem?
    private var offsetMenuItem: NSMenuItem?
    private var positionModeMenuItem: NSMenuItem?

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Lyrisland")
        }

        let menu = NSMenu()

        // Now playing info (disabled, just for display)
        trackMenuItem = NSMenuItem(title: String(localized: "menu.no_track"), action: nil, keyEquivalent: "")
        trackMenuItem?.isEnabled = false
        menu.addItem(trackMenuItem!)

        sourceMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        sourceMenuItem?.isEnabled = false
        sourceMenuItem?.isHidden = true
        menu.addItem(sourceMenuItem!)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: String(localized: "menu.show_hide"), action: #selector(toggleIsland), keyEquivalent: "l"))

        dualLineMenuItem = NSMenuItem(title: String(localized: "menu.dual_line"), action: #selector(toggleDualLine), keyEquivalent: "d")
        dualLineMenuItem?.state = appState.dualLineMode ? .on : .off
        menu.addItem(dualLineMenuItem!)

        showArtworkMenuItem = NSMenuItem(
            title: String(localized: "menu.show_artwork"),
            action: #selector(toggleArtwork),
            keyEquivalent: "a"
        )
        showArtworkMenuItem?.state = appState.showArtwork ? .on : .off
        menu.addItem(showArtworkMenuItem!)

        let isAttached = UserDefaults.standard.islandPositionMode == .attached
        positionModeMenuItem = NSMenuItem(
            title: isAttached ? String(localized: "menu.position.detach") : String(localized: "menu.position.attach"),
            action: #selector(togglePositionMode),
            keyEquivalent: "p"
        )
        positionModeMenuItem?.target = self
        menu.addItem(positionModeMenuItem!)

        menu.addItem(.separator())

        // Offset controls
        let offsetHeader = NSMenuItem(title: String(localized: "menu.offset"), action: nil, keyEquivalent: "")
        offsetHeader.isEnabled = false
        menu.addItem(offsetHeader)

        offsetMenuItem = NSMenuItem(title: String(format: String(localized: "menu.offset.value"), 0.0), action: nil, keyEquivalent: "")
        offsetMenuItem?.isEnabled = false
        menu.addItem(offsetMenuItem!)

        menu.addItem(NSMenuItem(title: String(localized: "menu.offset.earlier"), action: #selector(offsetEarlier), keyEquivalent: "["))
        menu.addItem(NSMenuItem(title: String(localized: "menu.offset.later"), action: #selector(offsetLater), keyEquivalent: "]"))
        menu.addItem(NSMenuItem(title: String(localized: "menu.offset.reset"), action: #selector(offsetReset), keyEquivalent: "0"))

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.quit"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func updateMenuInfo() {
        if let state = spotifyService.fetchPlaybackState() {
            trackMenuItem?.title = "\(state.title) — \(state.artist)"
        } else {
            trackMenuItem?.title = String(localized: "menu.no_track")
        }

        if let source = lyricsManager.currentLyrics?.source {
            sourceMenuItem?.title = "Source: \(source)"
            sourceMenuItem?.isHidden = false
        } else {
            sourceMenuItem?.isHidden = true
        }

        let offset = lyricsManager.userOffset
        offsetMenuItem?.title = String(format: String(localized: "menu.offset.value"), offset)
    }

    // MARK: - Island Panel

    private func setupIslandPanel() {
        let contentView = IslandContentView(
            syncEngine: syncEngine,
            lyricsManager: lyricsManager,
            appState: appState
        )
        islandPanel = DynamicIslandPanel(contentView: contentView)
        islandPanel?.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(positionModeDidChange),
            name: .islandPositionModeChanged,
            object: nil
        )
    }

    @objc private func positionModeDidChange() {
        updatePositionModeMenuItem()
    }

    // MARK: - Playback Monitoring

    private enum PollRate: TimeInterval {
        case playing = 0.2 // 200ms — smooth sync
        case paused = 1.0 // 1s — just watch for resume
        case notRunning = 3.0 // 3s — check if Spotify launched
    }

    private var pollTimer: Timer?
    private var currentPollRate: PollRate = .notRunning

    private func startPlaybackMonitoring() {
        setPollRate(.playing)
    }

    private func setPollRate(_ rate: PollRate) {
        guard rate != currentPollRate else { return }
        logDebug("Poll rate changed: \(currentPollRate) → \(rate)")
        currentPollRate = rate
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: rate.rawValue, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollSpotify() }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private var lastTrackId: String?
    private var pollCount: Int = 0

    private func pollSpotify() {
        guard let state = spotifyService.fetchPlaybackState() else {
            syncEngine.calibrate(position: 0, isPlaying: false)
            setPollRate(.notRunning)
            return
        }

        syncEngine.calibrate(position: state.position, isPlaying: state.isPlaying)
        syncEngine.setTrackId(state.trackId)
        syncEngine.setArtworkURL(state.artworkURL)
        setPollRate(state.isPlaying ? .playing : .paused)

        // Track changed → fetch new lyrics
        let trackChanged = state.trackId != lastTrackId
        if trackChanged {
            lastTrackId = state.trackId
            lyricsManager.resetOffset()
            Task {
                let track = TrackInfo(
                    id: state.trackId,
                    title: state.title,
                    artist: state.artist,
                    album: state.album,
                    durationMs: state.durationMs
                )
                await lyricsManager.loadLyrics(for: track)
                updateMenuInfo()
            }
        }

        // Refresh menu bar info periodically (every ~1s when playing)
        pollCount += 1
        if trackChanged || pollCount % 5 == 0 {
            updateMenuInfo()
        }
    }

    // MARK: - Actions

    @objc private func toggleDualLine() {
        appState.dualLineMode.toggle()
        dualLineMenuItem?.state = appState.dualLineMode ? .on : .off
    }

    @objc private func toggleArtwork() {
        appState.showArtwork.toggle()
        showArtworkMenuItem?.state = appState.showArtwork ? .on : .off
    }

    @objc private func togglePositionMode() {
        guard let panel = islandPanel else { return }
        let newMode: IslandPositionMode = panel.positionMode == .attached ? .detached : .attached
        panel.setPositionMode(newMode)
        updatePositionModeMenuItem()
    }

    private func updatePositionModeMenuItem() {
        guard let panel = islandPanel else { return }
        positionModeMenuItem?.title = panel.positionMode == .attached
            ? String(localized: "menu.position.detach")
            : String(localized: "menu.position.attach")
    }

    @objc private func toggleIsland() {
        if islandPanel?.isVisible == true {
            islandPanel?.orderOut(nil)
        } else {
            islandPanel?.orderFrontRegardless()
        }
    }

    @objc private func offsetEarlier() {
        lyricsManager.adjustOffset(by: -0.5)
        updateMenuInfo()
    }

    @objc private func offsetLater() {
        lyricsManager.adjustOffset(by: 0.5)
        updateMenuInfo()
    }

    @objc private func offsetReset() {
        lyricsManager.resetOffset()
        updateMenuInfo()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
