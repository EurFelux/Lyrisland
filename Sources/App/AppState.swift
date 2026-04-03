import AppKit
import Combine
import Foundation
import SwiftUI

/// Tracks the overall app readiness state for onboarding and status display.
@MainActor
final class AppState: ObservableObject {
    enum SpotifyStatus: Equatable {
        case notInstalled
        case notRunning
        case running
    }

    enum PermissionStatus: Equatable {
        case unknown
        case granted
        case denied
    }

    @Published private(set) var spotifyStatus: SpotifyStatus = .notRunning
    @Published private(set) var permissionStatus: PermissionStatus = .unknown
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var dualLineMode: Bool {
        didSet { UserDefaults.standard.set(dualLineMode, forKey: "dualLineMode") }
    }

    @Published var showArtwork: Bool {
        didSet { UserDefaults.standard.set(showArtwork, forKey: "showArtwork") }
    }

    @Published var lyricsAlignment: String {
        didSet { UserDefaults.standard.set(lyricsAlignment, forKey: "lyricsAlignment") }
    }

    private var defaultsObserver: AnyCancellable?

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        dualLineMode = UserDefaults.standard.bool(forKey: "dualLineMode")
        // Default to true for new installs (key absent returns false, so use register)
        UserDefaults.standard.register(defaults: ["showArtwork": true, "lyricsAlignment": "center"])
        showArtwork = UserDefaults.standard.bool(forKey: "showArtwork")
        lyricsAlignment = UserDefaults.standard.string(forKey: "lyricsAlignment") ?? "center"

        // Sync changes from @AppStorage (Settings window) back to @Published properties
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newDualLine = UserDefaults.standard.bool(forKey: "dualLineMode")
                let newShowArtwork = UserDefaults.standard.bool(forKey: "showArtwork")
                let newAlignment = UserDefaults.standard.string(forKey: "lyricsAlignment") ?? "left"
                if dualLineMode != newDualLine { dualLineMode = newDualLine }
                if showArtwork != newShowArtwork { showArtwork = newShowArtwork }
                if lyricsAlignment != newAlignment { lyricsAlignment = newAlignment }
            }
    }

    var resolvedLyricsAlignment: Alignment {
        switch lyricsAlignment {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
    }

    var resolvedHorizontalAlignment: HorizontalAlignment {
        switch lyricsAlignment {
        case "center": .center
        case "right": .trailing
        default: .leading
        }
    }

    // MARK: - Spotify Checks

    /// Check if Spotify.app is installed.
    func checkSpotifyInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
    }

    /// Check if Spotify is currently running.
    func checkSpotifyRunning() -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first != nil
    }

    /// Attempt an AppleScript call to test permission. Updates status.
    func checkPermission() {
        let testScript = """
        tell application "System Events"
            return name of first process whose bundle identifier is "com.spotify.client"
        end tell
        """
        guard let script = NSAppleScript(source: testScript) else {
            permissionStatus = .denied
            return
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        permissionStatus = (error == nil) ? .granted : .unknown
    }

    /// Refresh all status checks.
    func refresh() {
        if !checkSpotifyInstalled() {
            spotifyStatus = .notInstalled
        } else if checkSpotifyRunning() {
            spotifyStatus = .running
        } else {
            spotifyStatus = .notRunning
        }
        checkPermission()
    }
}
