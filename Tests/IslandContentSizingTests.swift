import AppKit
@testable import Lyrisland
import Testing

struct IslandContentSizingTests {
    @Test("Compact island uses Dynamic Island-sized width")
    func compactWidth() {
        #expect(IslandContentView.size(for: .compact).width == 220)
        #expect(IslandContentView.size(for: .compact, attached: true).width == 220)
    }

    @Test("Compact single-line height is not inflated by artwork")
    func compactHeight() {
        #expect(IslandContentView.size(for: .compact, dualLine: false, artwork: true).height == 58)
        #expect(IslandContentView.size(for: .compact, dualLine: false, artwork: false).height == 58)
    }

    @Test("Expanded and full island widths stay unchanged")
    func expandedAndFullWidths() {
        #expect(IslandContentView.size(for: .expanded, artwork: true).width == 450)
        #expect(IslandContentView.size(for: .expanded, artwork: false).width == 380)
        #expect(IslandContentView.size(for: .full, artwork: true).width == 540)
        #expect(IslandContentView.size(for: .full, artwork: false).width == 400)
    }
}
