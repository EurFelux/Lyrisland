import AppKit

/// Tracks which auxiliary windows (settings, help, onboarding, lyrics picker)
/// are currently open.
///
/// Lyrisland runs as an `LSUIElement` app, which macOS refuses to activate, so
/// those windows would open behind whatever app the user was looking at. The app
/// therefore becomes a regular app for as long as one of them is open. Membership
/// is recorded explicitly rather than derived from `NSWindow.isVisible`, which
/// also reports `false` for a window that is merely hidden (⌘H) or minimized —
/// that would drop the Dock icon while a window is still open.
struct AuxiliaryWindowRegistry {
    private var openWindows: Set<ObjectIdentifier> = []

    var isEmpty: Bool {
        openWindows.isEmpty
    }

    mutating func opened(_ window: NSWindow) {
        openWindows.insert(ObjectIdentifier(window))
    }

    /// - Returns: `true` when the closed window was the last one still open.
    @discardableResult
    mutating func closed(_ window: NSWindow) -> Bool {
        openWindows.remove(ObjectIdentifier(window))
        return openWindows.isEmpty
    }
}
