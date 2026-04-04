import AppKit
import SwiftUI

// MARK: - Adaptive Content Color Environment

private struct ContentColorKey: EnvironmentKey {
    static let defaultValue: Color = .white
}

extension EnvironmentValues {
    /// Adaptive text/icon color for the island, set at the root based on background luminance.
    var contentColor: Color {
        get { self[ContentColorKey.self] }
        set { self[ContentColorKey.self] = newValue }
    }
}

// MARK: - Color Extensions

extension Color {
    /// W3C relative luminance per WCAG 2.1 definition.
    /// Linearizes sRGB gamma before applying `L = 0.2126*R + 0.7152*G + 0.0722*B`.
    var relativeLuminance: Double {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        func linearize(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = linearize(ns.redComponent)
        let g = linearize(ns.greenComponent)
        let b = linearize(ns.blueComponent)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Create a Color from a hex string like "#141414" or "141414".
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// Convert to hex string like "#141414".
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
