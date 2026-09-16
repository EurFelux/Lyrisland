import SwiftUI

@main
struct LyrislandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement app — no main window, only the floating island + menu bar.
        // `App` still requires a scene, so this placeholder stands in for one.
        // AppDelegate owns the real settings window; while an auxiliary window is
        // open the app temporarily becomes a regular app and gains a menu bar, so
        // the stock Settings… item is removed to keep it from opening a second,
        // duplicate settings window.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {}
        }
    }
}
