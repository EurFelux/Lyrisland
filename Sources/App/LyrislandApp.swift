import SwiftUI

@main
struct LyrislandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement app — no main window, only the floating island + menu bar
        Settings {
            EmptyView()
        }
    }
}
