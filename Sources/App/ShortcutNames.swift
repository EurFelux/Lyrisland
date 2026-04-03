import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleLyrics = Self("toggleLyrics", default: .init(.l, modifiers: .command))
    static let openSettings = Self("openSettings", default: .init(.comma, modifiers: .command))
    static let openHelp = Self("openHelp", default: .init(.slash, modifiers: [.command, .shift]))
    static let quitApp = Self("quitApp", default: .init(.q, modifiers: .command))

    /// All shortcut names used by the app, for iteration in settings UI.
    static let allCases: [KeyboardShortcuts.Name] = [
        .toggleLyrics,
        .openSettings,
        .openHelp,
        .quitApp,
    ]
}
