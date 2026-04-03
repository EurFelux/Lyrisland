import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandPanel: DynamicIslandPanel?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private let spotifyService = SpotifyAppleScriptService()
    private let lyricsManager = LyricsManager()
    private let syncEngine = PlaybackSyncEngine()
    private let appState = AppState()

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

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "menu.settings"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: String(localized: "menu.quit"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func updateMenuInfo(state: SpotifyPlaybackState? = nil) {
        if let state {
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
            selector: #selector(positionModeSettingsChanged(_:)),
            name: .islandPositionModeSettingsChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOffsetAdjust(_:)),
            name: .lyricsOffsetAdjust,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOffsetReset),
            name: .lyricsOffsetReset,
            object: nil
        )
    }

    @objc private func positionModeSettingsChanged(_ notification: Notification) {
        guard let mode = notification.object as? IslandPositionMode else { return }
        islandPanel?.setPositionMode(mode)
    }

    @objc private func handleOffsetAdjust(_ notification: Notification) {
        guard let delta = notification.object as? Double else { return }
        lyricsManager.adjustOffset(by: delta)
        syncOffsetToDefaults()
    }

    @objc private func handleOffsetReset() {
        lyricsManager.resetOffset()
        syncOffsetToDefaults()
    }

    private func syncOffsetToDefaults() {
        UserDefaults.standard.set(lyricsManager.userOffset, forKey: "currentLyricsOffset")
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
        Task {
            guard let state = await spotifyService.fetchPlaybackState() else {
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
                UserDefaults.standard.set(0.0, forKey: "currentLyricsOffset")
                let track = TrackInfo(
                    id: state.trackId,
                    title: state.title,
                    artist: state.artist,
                    album: state.album,
                    durationMs: state.durationMs
                )
                await lyricsManager.loadLyrics(for: track)
            }

            // Refresh menu bar info periodically (every ~1s when playing)
            pollCount += 1
            if trackChanged || pollCount % 5 == 0 {
                updateMenuInfo(state: state)
            }
        }
    }

    // MARK: - Actions

    @objc private func toggleIsland() {
        if islandPanel?.isVisible == true {
            islandPanel?.orderOut(nil)
        } else {
            islandPanel?.orderFrontRegardless()
        }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = String(localized: "menu.settings")
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            settingsWindow = window
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
