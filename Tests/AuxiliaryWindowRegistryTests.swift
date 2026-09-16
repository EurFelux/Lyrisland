import AppKit
@testable import Lyrisland
import Testing

@MainActor
struct AuxiliaryWindowRegistryTests {
    private func makeWindow() -> NSWindow {
        NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    }

    @Test("A registry with no windows is empty")
    func startsEmpty() {
        #expect(AuxiliaryWindowRegistry().isEmpty)
    }

    @Test("Closing one of two windows keeps the app in regular mode")
    func closingOneOfTwo() {
        var registry = AuxiliaryWindowRegistry()
        let settings = makeWindow()
        let help = makeWindow()
        registry.opened(settings)
        registry.opened(help)

        #expect(registry.closed(help) == false)
        #expect(!registry.isEmpty)
        #expect(registry.closed(settings) == true)
        #expect(registry.isEmpty)
    }

    @Test("Re-opening an already-tracked window does not double-count it")
    func reopenIsIdempotent() {
        var registry = AuxiliaryWindowRegistry()
        let settings = makeWindow()
        registry.opened(settings)
        registry.opened(settings)

        #expect(registry.closed(settings) == true)
    }

    @Test("Closing an untracked window leaves tracked windows alone")
    func closingUntrackedWindow() {
        var registry = AuxiliaryWindowRegistry()
        let settings = makeWindow()
        registry.opened(settings)

        #expect(registry.closed(makeWindow()) == false)
        #expect(!registry.isEmpty)
    }
}
