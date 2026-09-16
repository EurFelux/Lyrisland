import Foundation
@testable import Lyrisland
import Testing

struct IslandPlacementTests {
    private let builtInScreen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test("Attached island is centered horizontally and flush with the screen top")
    func attachedOrigin() {
        let size = CGSize(width: 273, height: 71)
        let origin = IslandPlacement.attachedOrigin(panelSize: size, screenFrame: builtInScreen)

        #expect(origin.x == 619.5, "actual x=\(origin.x)")
        #expect(origin.y == 911, "actual y=\(origin.y)")
    }

    @Test("A wider panel re-centers instead of keeping the old origin")
    func reCentersOnSizeChange() {
        // The panel is created at the plain compact width and grows to the
        // notch-hugging width once the screen is known.
        let initial = IslandPlacement.attachedOrigin(
            panelSize: CGSize(width: 220, height: 38),
            screenFrame: builtInScreen
        )
        let corrected = IslandPlacement.attachedOrigin(
            panelSize: CGSize(width: 273, height: 71),
            screenFrame: builtInScreen
        )

        #expect(initial.x == 646)
        #expect(corrected.x == 619.5)
        #expect(corrected.y == 911)
    }

    @Test("Attached origin follows the screen it is given")
    func attachedOriginOnSecondaryScreen() {
        let secondary = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let size = CGSize(width: 220, height: 38)
        let origin = IslandPlacement.attachedOrigin(panelSize: size, screenFrame: secondary)

        #expect(origin.x == secondary.midX - 110)
        #expect(origin.y == secondary.maxY - 38)
    }

    @Test("Detached fallback sits below the menu bar with a gap")
    func detachedFallback() {
        let visible = CGRect(x: 0, y: 0, width: 1512, height: 944)
        let size = CGSize(width: 220, height: 38)
        let origin = IslandPlacement.detachedFallbackOrigin(panelSize: size, visibleFrame: visible)

        #expect(origin.x == 646, "actual x=\(origin.x)")
        #expect(origin.y == 894, "actual y=\(origin.y)")
    }
}
