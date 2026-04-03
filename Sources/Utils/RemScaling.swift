import SwiftUI

// MARK: - Environment Key

private struct RootFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

extension EnvironmentValues {
    var rootFontSize: CGFloat {
        get { self[RootFontSizeKey.self] }
        set { self[RootFontSizeKey.self] = newValue }
    }
}

// MARK: - rem helper

extension CGFloat {
    /// Computes an absolute font size from a `rem` multiplier and a root size.
    /// Usage: `CGFloat.rem(0.75, root: rootFontSize)` -> 12 when root = 16.
    static func rem(_ multiplier: CGFloat, root: CGFloat) -> CGFloat {
        multiplier * root
    }
}
