import AppKit
import SwiftUI

/// A transparent NSButton wrapped for SwiftUI, used as an overlay to make
/// areas clickable inside DynamicIslandPanel. The panel's mouse handling
/// forwards events to NSControl subviews via hitTest, so a real NSButton
/// is needed — SwiftUI Button does not render as NSControl.
struct NativeButtonOverlay: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        button.isTransparent = true
        button.isBordered = false
        button.title = ""
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        return button
    }

    func updateNSView(_: NSButton, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func clicked() {
            action()
        }
    }
}
