import SwiftUI

/// Shape for the attached island: inverse (concave) corners at the top,
/// regular rounded corners at the bottom.
struct AttachedIslandShape: Shape {
    var bottomRadius: CGFloat
    var inverseRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let ir = inverseRadius
        let br = bottomRadius

        var path = Path()

        // Top-left corner
        path.move(to: CGPoint(x: 0, y: 0))

        // Left inverse corner: concave arc from (0, 0) to (ir, ir)
        path.addArc(
            center: CGPoint(x: 0, y: ir),
            radius: ir,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Left body edge down to bottom-left corner
        path.addLine(to: CGPoint(x: ir, y: h - br))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: ir + br, y: h - br),
            radius: br,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: w - ir - br, y: h))

        // Bottom-right corner
        path.addArc(
            center: CGPoint(x: w - ir - br, y: h - br),
            radius: br,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )

        // Right body edge up to right inverse corner
        path.addLine(to: CGPoint(x: w - ir, y: ir))

        // Right inverse corner: concave arc from (w-ir, ir) to (w, 0)
        path.addArc(
            center: CGPoint(x: w, y: ir),
            radius: ir,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}
