import AppKit
@testable import Lyrisland
import Testing

struct NotchHuggingLayoutTests {
    @Test("Notch-hugging size spans both ears plus the notch width")
    func spansEarsAndNotch() {
        let s = IslandContentView.notchHuggingSize(
            notchWidth: 200, notchHeight: 37, earWidth: 40, lyricsRowHeight: 26
        )
        #expect(s.width == 280) // 40 + 200 + 40
        #expect(s.height == 63) // 37 + 26
    }

    @Test("Notch-hugging height grows with a taller (dual-line) lyrics row")
    func tallerLyricsRow() {
        let single = IslandContentView.notchHuggingSize(
            notchWidth: 180, notchHeight: 32, earWidth: 40, lyricsRowHeight: 26
        )
        let dual = IslandContentView.notchHuggingSize(
            notchWidth: 180, notchHeight: 32, earWidth: 40, lyricsRowHeight: 44
        )
        #expect(dual.height - single.height == 18) // 44 - 26
        #expect(dual.width == single.width) // lyrics height doesn't affect width
    }

    @Test("notchWidth is the gap between the two auxiliary top areas")
    func notchWidthGap() {
        let left = NSRect(x: 0, y: 0, width: 500, height: 38) // maxX = 500
        let right = NSRect(x: 700, y: 0, width: 500, height: 38) // minX = 700
        #expect(NSScreen.notchWidth(auxiliaryLeft: left, auxiliaryRight: right) == 200)
    }

    @Test("notchWidth is nil when an auxiliary area is missing")
    func notchWidthMissing() {
        #expect(NSScreen.notchWidth(auxiliaryLeft: nil, auxiliaryRight: nil) == nil)
        #expect(NSScreen.notchWidth(
            auxiliaryLeft: NSRect(x: 0, y: 0, width: 1, height: 1), auxiliaryRight: nil
        ) == nil)
    }

    @Test("Notch-hugging layout only applies to compact + attached + measurable notch")
    func gating() {
        // Happy path: compact, attached, notch present.
        #expect(IslandContentView.usesNotchHugging(state: .compact, attached: true, notchWidth: 180))
        // Detached → horizontal layout.
        #expect(!IslandContentView.usesNotchHugging(state: .compact, attached: false, notchWidth: 180))
        // Non-compact states → horizontal layout.
        #expect(!IslandContentView.usesNotchHugging(state: .expanded, attached: true, notchWidth: 180))
        #expect(!IslandContentView.usesNotchHugging(state: .full, attached: true, notchWidth: 180))
        // External / non-notched display → horizontal layout.
        #expect(!IslandContentView.usesNotchHugging(state: .compact, attached: true, notchWidth: nil))
        #expect(!IslandContentView.usesNotchHugging(state: .compact, attached: true, notchWidth: 0))
    }
}
