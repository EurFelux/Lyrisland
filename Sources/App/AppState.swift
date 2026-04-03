import AppKit
import Foundation

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

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        dualLineMode = UserDefaults.standard.bool(forKey: "dualLineMode")
        // Default to true for new installs (key absent returns false, so use register)
        UserDefaults.standard.register(defaults: ["showArtwork": true])
        showArtwork = UserDefaults.standard.bool(forKey: "showArtwork")
    }

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
