import Foundation
@testable import Lyrisland
import Testing

struct PanelPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let panel = CGSize(width: 230, height: 370)

    @Test("Panel opens to the right of the window with the tops aligned")
    func opensToTheRight() {
        let window = CGRect(x: 400, y: 300, width: 640, height: 460)
        let origin = PanelPlacement.origin(forPanelSize: panel, anchoredTo: window, within: screen)

        #expect(origin.x == window.maxX + PanelPlacement.gap)
        #expect(origin.y == window.maxY - panel.height)
    }

    @Test("Panel flips to the left when it would overflow the right edge")
    func flipsToTheLeft() {
        let window = CGRect(x: 1100, y: 300, width: 640, height: 460)
        let origin = PanelPlacement.origin(forPanelSize: panel, anchoredTo: window, within: screen)

        #expect(origin.x == window.minX - PanelPlacement.gap - panel.width)
    }

    @Test("Panel stays on screen when neither side has room")
    func clampsWhenNoSideFits() {
        let narrowScreen = CGRect(x: 0, y: 0, width: 800, height: 600)
        let window = CGRect(x: 40, y: 40, width: 700, height: 500)
        let origin = PanelPlacement.origin(forPanelSize: panel, anchoredTo: window, within: narrowScreen)

        #expect(origin.x >= narrowScreen.minX)
        #expect(origin.x + panel.width <= narrowScreen.maxX)
    }

    @Test("Panel is pushed down when the window sits near the top edge")
    func clampsToTopEdge() {
        let window = CGRect(x: 400, y: 900, width: 640, height: 460)
        let origin = PanelPlacement.origin(forPanelSize: panel, anchoredTo: window, within: screen)

        #expect(origin.y + panel.height <= screen.maxY)
        #expect(origin.y >= screen.minY)
    }

    @Test("Origins are expressed in the coordinate space of the given screen")
    func respectsScreenOrigin() {
        // A second display to the left of the main one has a negative origin.
        let secondary = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let window = CGRect(x: -1500, y: 300, width: 640, height: 460)
        let origin = PanelPlacement.origin(forPanelSize: panel, anchoredTo: window, within: secondary)

        #expect(origin.x >= secondary.minX)
        #expect(origin.x + panel.width <= secondary.maxX)
    }
}
