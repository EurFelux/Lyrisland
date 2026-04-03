import Foundation

/// Whether the island is attached to the menu bar or freely draggable.
enum IslandPositionMode: String {
    /// Centered in the menu bar region, like an iPhone Dynamic Island.
    case attached
    /// Freely draggable to any screen position.
    case detached
}

// MARK: - UserDefaults Persistence

extension UserDefaults {
    private enum Keys {
        static let positionMode = "islandPositionMode"
        static let detachedX = "islandDetachedX"
        static let detachedY = "islandDetachedY"
        static let hasDetachedPosition = "islandHasDetachedPosition"
    }

    var islandPositionMode: IslandPositionMode {
        get {
            guard let raw = string(forKey: Keys.positionMode) else { return .attached }
            return IslandPositionMode(rawValue: raw) ?? .attached
        }
        set { set(newValue.rawValue, forKey: Keys.positionMode) }
    }

    var islandDetachedPosition: NSPoint? {
        get {
            guard bool(forKey: Keys.hasDetachedPosition) else { return nil }
            return NSPoint(
                x: double(forKey: Keys.detachedX),
                y: double(forKey: Keys.detachedY)
            )
        }
        set {
            if let point = newValue {
                set(true, forKey: Keys.hasDetachedPosition)
                set(point.x, forKey: Keys.detachedX)
                set(point.y, forKey: Keys.detachedY)
            } else {
                set(false, forKey: Keys.hasDetachedPosition)
            }
        }
    }
}
