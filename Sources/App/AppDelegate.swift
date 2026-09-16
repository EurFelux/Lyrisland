import AppKit
import KeyboardShortcuts
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandPanel: DynamicIslandPanel?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var helpWindow: NSWindow?
    private var lyricsPickerWindow: NSWindow?
    private var auxiliaryWindows = AuxiliaryWindowRegistry()
    private var colorPanelObservation: NSKeyValueObservation?
    private var statusItem: NSStatusItem?
    private let spotifyService = SpotifyAppleScriptService()
    let lyricsManager = LyricsManager()
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
        bringToFront(window)

        onboardingWindow = window
    }

    private func launchMainUI() {
        syncEngine.lyricsManager = lyricsManager
        syncEngine.spotifyService = spotifyService
        setupIslandPanel()
        startPlaybackMonitoring()
    }

    // MARK: - Menu Bar

    private var trackMenuItem: NSMenuItem?
    private var sourceMenuItem: NSMenuItem?
    private var chooseLyricsMenuItem: NSMenuItem?

    private var toggleMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var helpMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let icon = NSImage(named: "TrayIcon") {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        // Now playing info (disabled, just for display)
        trackMenuItem = NSMenuItem(title: String(localized: "menu.no_track"), action: nil, keyEquivalent: "")
        trackMenuItem?.isEnabled = false
        menu.addItem(trackMenuItem!)

        sourceMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        sourceMenuItem?.isEnabled = false
        sourceMenuItem?.isHidden = true
        menu.addItem(sourceMenuItem!)

        chooseLyricsMenuItem = NSMenuItem(
            title: String(localized: "menu.choose_lyrics"),
            action: #selector(openLyricsPicker),
            keyEquivalent: ""
        )
        chooseLyricsMenuItem?.isHidden = true
        menu.addItem(chooseLyricsMenuItem!)

        menu.addItem(.separator())

        toggleMenuItem = NSMenuItem(title: String(localized: "menu.show_hide"), action: #selector(toggleIsland), keyEquivalent: "")
        menu.addItem(toggleMenuItem!)

        menu.addItem(.separator())
        settingsMenuItem = NSMenuItem(title: String(localized: "menu.settings"), action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(settingsMenuItem!)
        helpMenuItem = NSMenuItem(title: String(localized: "menu.help"), action: #selector(openHelp), keyEquivalent: "")
        menu.addItem(helpMenuItem!)
        quitMenuItem = NSMenuItem(title: String(localized: "menu.quit"), action: #selector(quitApp), keyEquivalent: "")
        menu.addItem(quitMenuItem!)

        statusItem?.menu = menu

        syncMenuItemShortcuts()
        setupGlobalShortcuts()
    }

    private func syncMenuItemShortcuts() {
        toggleMenuItem?.setShortcut(for: .toggleLyrics)
        settingsMenuItem?.setShortcut(for: .openSettings)
        helpMenuItem?.setShortcut(for: .openHelp)
        quitMenuItem?.setShortcut(for: .quitApp)
    }

    private func setupGlobalShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleLyrics) { [weak self] in
            self?.toggleIsland()
        }
        KeyboardShortcuts.onKeyUp(for: .openSettings) { [weak self] in
            self?.openSettings()
        }
        KeyboardShortcuts.onKeyUp(for: .openHelp) { [weak self] in
            self?.openHelp()
        }
        KeyboardShortcuts.onKeyUp(for: .quitApp) { [weak self] in
            self?.quitApp()
        }
    }

    private func updateMenuInfo(state: SpotifyPlaybackState? = nil) {
        if let state {
            trackMenuItem?.title = "\(state.title) — \(state.artist)"
        } else {
            trackMenuItem?.title = String(localized: "menu.no_track")
        }

        if let source = lyricsManager.currentLyrics?.source {
            sourceMenuItem?.title = "\(String(localized: "menu.switch_source")): \(ProviderSettings.displayName(for: source))"
            sourceMenuItem?.isHidden = false
            chooseLyricsMenuItem?.isHidden = false
        } else {
            sourceMenuItem?.isHidden = true
            chooseLyricsMenuItem?.isHidden = lyricsManager.currentTrack == nil
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenLyricsPicker),
            name: .openLyricsPicker,
            object: nil
        )
    }

    @objc private func handleOpenLyricsPicker() {
        openLyricsPicker()
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
            syncEngine.setTrackInfo(title: state.title, artist: state.artist)
            setPollRate(state.isPlaying ? .playing : .paused)

            // Track changed → fetch new lyrics
            let trackChanged = state.trackId != lastTrackId
            if trackChanged {
                lastTrackId = state.trackId
                lyricsPickerWindow?.close()
                lyricsPickerWindow = nil
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

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Window Actions

extension AppDelegate {
    @objc private func openLyricsPicker() {
        guard let track = lyricsManager.currentTrack else { return }

        // Always create a fresh window for the current track
        let previousWindow = lyricsPickerWindow
        let pickerView = LyricsPickerView(lyricsManager: lyricsManager, track: track)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = String(localized: "picker.title")
        window.contentView = NSHostingView(rootView: pickerView)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(white: 0.1, alpha: 1)
        window.minSize = NSSize(width: 380, height: 300)
        lyricsPickerWindow = window
        bringToFront(window)
        // Closed last so the app never briefly drops back to accessory mode
        previousWindow?.close()
    }

    @objc private func toggleIsland() {
        if islandPanel?.isVisible == true {
            islandPanel?.orderOut(nil)
        } else {
            islandPanel?.orderFrontRegardless()
        }
    }

    @objc private func openHelp() {
        if let window = helpWindow {
            bringToFront(window)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = String(localized: "menu.help")
            window.contentView = NSHostingView(rootView: HelpView())
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(white: 0.1, alpha: 1)
            helpWindow = window
            bringToFront(window)
        }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            bringToFront(window)
        } else {
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: SettingsView.minimumSize),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = String(localized: "settings.window.title")
            window.contentView = NSHostingView(rootView: SettingsView(lyricsManager: lyricsManager))
            window.contentMinSize = SettingsView.minimumSize
            observeSharedColorPanel()
            window.isReleasedWhenClosed = false
            settingsWindow = window
            bringToFront(window)
        }
    }

    /// Shows an auxiliary window on top of whatever else is on screen.
    ///
    /// Lyrisland is an `LSUIElement` app, so it is never the active app when a
    /// window is requested from the menu bar or a global shortcut. macOS 14 made
    /// activation cooperative and routinely refuses an accessory app's request,
    /// which left the window buried behind the app the user was looking at.
    /// Switching to `.regular` for as long as a window is open makes the app a
    /// normal activation target (at the cost of a temporary Dock icon);
    /// `.moveToActiveSpace` pulls a window left open on another Space over to the
    /// current one instead of switching Spaces, and `orderFrontRegardless` keeps
    /// the window visible even if activation is still denied.
    /// Keeps the shared `NSColorPanel` on the same display as the settings window.
    ///
    /// The panel is a process-wide singleton that reopens wherever it was last
    /// left, so on a multi-display setup it happily appears on a screen the
    /// settings window is not even on. It never becomes the key window (the
    /// settings window keeps key while the panel is up), so its visibility is
    /// observed directly rather than through the key-window notifications.
    private func observeSharedColorPanel() {
        guard colorPanelObservation == nil else { return }
        colorPanelObservation = NSColorPanel.shared.observe(\.isVisible, options: [.new]) { [weak self] panel, change in
            guard change.newValue == true else { return }
            Task { @MainActor in
                self?.placeNearSettingsWindow(panel)
            }
        }
    }

    /// Moves `panel` beside the settings window, but only when it opened on
    /// another screen, so a spot the user picked on this screen is left alone.
    private func placeNearSettingsWindow(_ panel: NSPanel) {
        // Compared by frame: `NSScreen` instances are not guaranteed to be
        // identical across calls, but one frame belongs to exactly one display.
        guard let window = settingsWindow, window.isVisible,
              let screen = window.screen, panel.screen?.frame != screen.frame
        else { return }

        panel.setFrameOrigin(
            PanelPlacement.origin(
                forPanelSize: panel.frame.size,
                anchoredTo: window.frame,
                within: screen.visibleFrame
            )
        )
    }

    private func bringToFront(_ window: NSWindow) {
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.delegate = self
        auxiliaryWindows.opened(window)
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    /// Drops the Dock icon again once the last auxiliary window is gone.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              auxiliaryWindows.closed(window)
        else { return }
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_: NSMenu) {
        KeyboardShortcuts.disable(KeyboardShortcuts.Name.allCases)
    }

    func menuDidClose(_: NSMenu) {
        KeyboardShortcuts.enable(KeyboardShortcuts.Name.allCases)
    }
}
