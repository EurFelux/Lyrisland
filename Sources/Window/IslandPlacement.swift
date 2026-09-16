import Foundation

/// Where the island panel sits on screen.
///
/// Attached mode has a single invariant: horizontally centered on the screen and
/// flush with its top edge. Because the panel's width depends on the screen (the
/// notch-hugging layout is wider than the plain compact one), the origin has to
/// be recomputed from the *current* size every time that size changes — a stale
/// origin leaves the island visibly off-center.
enum IslandPlacement {
    static func attachedOrigin(panelSize: CGSize, screenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height
        )
    }

    /// Default spot for detached mode before the user has dragged the island:
    /// centered under the menu bar.
    static func detachedFallbackOrigin(panelSize: CGSize, visibleFrame: CGRect, gap: CGFloat = 12) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.maxY - panelSize.height - gap
        )
    }
}
