import Foundation

/// Persists per-track lyrics provider overrides chosen by the user.
enum TrackLyricsOverride {
    private static let userDefaultsKey = "trackLyricsOverrides"
    private static let maxEntries = 500

    /// Get the user's preferred provider for a track, if any.
    static func preferredProvider(for trackId: String) -> String? {
        load()[trackId]
    }

    /// Save the user's preferred provider for a track.
    static func setPreferredProvider(_ provider: String, for trackId: String) {
        var overrides = load()
        overrides[trackId] = provider

        // Prune oldest entries if over limit.
        // Since we can't track insertion order cheaply, just trim to limit.
        if overrides.count > maxEntries {
            let excess = overrides.count - maxEntries
            let keysToRemove = Array(overrides.keys.prefix(excess))
            for key in keysToRemove {
                overrides.removeValue(forKey: key)
            }
        }

        save(overrides)
    }

    static func removePreference(for trackId: String) {
        var overrides = load()
        overrides.removeValue(forKey: trackId)
        save(overrides)
    }

    // MARK: - Persistence

    private static func load() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let overrides = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return overrides
    }

    private static func save(_ overrides: [String: String]) {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
