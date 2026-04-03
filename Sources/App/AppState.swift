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

    @Published var backgroundStyle: BackgroundStyle {
        didSet { UserDefaults.standard.set(backgroundStyle.rawValue, forKey: "backgroundStyle") }
    }

    @Published var rootFontSize: Double {
        didSet { UserDefaults.standard.set(rootFontSize, forKey: "rootFontSize") }
    }

    /// Hex string for the user's custom solid background color (e.g. "#141414").
    @Published var solidColorHex: String {
        didSet { UserDefaults.standard.set(solidColorHex, forKey: "solidColorHex") }
    }

    /// Resolved SwiftUI Color from the stored hex string.
    var solidColor: Color {
        Color(hex: solidColorHex) ?? Color(white: 0.08)
    }

    private var defaultsObserver: AnyCancellable?

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        dualLineMode = UserDefaults.standard.bool(forKey: "dualLineMode")
        // Default to true for new installs (key absent returns false, so use register)
        UserDefaults.standard.register(defaults: [
            "showArtwork": true,
            "lyricsAlignment": "center",
            "backgroundStyle": "solid",
            "solidColorHex": "#141414",
            "rootFontSize": 16.0,
        ])
        showArtwork = UserDefaults.standard.bool(forKey: "showArtwork")
        lyricsAlignment = UserDefaults.standard.string(forKey: "lyricsAlignment") ?? "center"
        backgroundStyle = BackgroundStyle(rawValue: UserDefaults.standard.string(forKey: "backgroundStyle") ?? "solid") ?? .solid
        solidColorHex = UserDefaults.standard.string(forKey: "solidColorHex") ?? "#141414"
        let storedFontSize = UserDefaults.standard.double(forKey: "rootFontSize")
        rootFontSize = storedFontSize > 0 ? storedFontSize : 16.0

        // Sync changes from @AppStorage (Settings window) back to @Published properties
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newDualLine = UserDefaults.standard.bool(forKey: "dualLineMode")
                let newShowArtwork = UserDefaults.standard.bool(forKey: "showArtwork")
                let newAlignment = UserDefaults.standard.string(forKey: "lyricsAlignment") ?? "center"
                let newBgStyle = BackgroundStyle(rawValue: UserDefaults.standard.string(forKey: "backgroundStyle") ?? "solid") ?? .solid
                if dualLineMode != newDualLine { dualLineMode = newDualLine }
                if showArtwork != newShowArtwork { showArtwork = newShowArtwork }
                if lyricsAlignment != newAlignment { lyricsAlignment = newAlignment }
                if backgroundStyle != newBgStyle { backgroundStyle = newBgStyle }
                let newSolidHex = UserDefaults.standard.string(forKey: "solidColorHex") ?? "#141414"
                if solidColorHex != newSolidHex { solidColorHex = newSolidHex }
                let newFontSize = UserDefaults.standard.double(forKey: "rootFontSize")
                let resolvedFontSize = newFontSize > 0 ? newFontSize : 16.0
                if rootFontSize != resolvedFontSize { rootFontSize = resolvedFontSize }
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
