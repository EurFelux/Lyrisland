import Foundation

/// Works out where a shared AppKit panel should open relative to the window that
/// asked for it.
///
/// `NSColorPanel` is a process-wide singleton that restores the position it was
/// last left at, so it happily opens on a different display than the settings
/// window that triggered it.
enum PanelPlacement {
    /// Gap between the anchor window and the panel.
    static let gap: CGFloat = 12

    /// The origin (bottom-left, in Cocoa screen coordinates) for a panel of `size`
    /// opened from `anchor`: beside the anchor — to its right where there is room,
    /// otherwise to its left — with the top edges aligned, always kept fully
    /// inside `bounds`.
    static func origin(forPanelSize size: CGSize, anchoredTo anchor: CGRect, within bounds: CGRect) -> CGPoint {
        var x = anchor.maxX + gap
        if x + size.width > bounds.maxX {
            let mirrored = anchor.minX - gap - size.width
            x = mirrored >= bounds.minX ? mirrored : bounds.maxX - size.width
        }

        let y = anchor.maxY - size.height
        return CGPoint(
            x: clamp(x, length: size.width, within: bounds.minX ... bounds.maxX),
            y: clamp(y, length: size.height, within: bounds.minY ... bounds.maxY)
        )
    }

    /// Keeps `origin ..< origin + length` inside `limits`, preferring the lower
    /// edge when the panel is larger than the space available.
    private static func clamp(_ origin: CGFloat, length: CGFloat, within limits: ClosedRange<CGFloat>) -> CGFloat {
        min(max(origin, limits.lowerBound), max(limits.lowerBound, limits.upperBound - length))
    }
}
