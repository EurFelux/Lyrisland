import Foundation

struct ProviderEntry: Codable, Identifiable, Equatable {
    var id: String // matches LyricsProvider.name
    var isEnabled: Bool
}

struct ProviderSettings: Codable, Equatable {
    var entries: [ProviderEntry]

    static let defaultEntries: [ProviderEntry] = [
        ProviderEntry(id: "lrclib", isEnabled: true),
        ProviderEntry(id: "musixmatch", isEnabled: true),
        ProviderEntry(id: "sodamusic", isEnabled: true),
        ProviderEntry(id: "netease", isEnabled: true),
    ]

    static let `default` = ProviderSettings(entries: defaultEntries)

    private static let userDefaultsKey = "providerSettings"

    static func load(from defaults: UserDefaults = .standard) -> ProviderSettings {
        guard let data = defaults.data(forKey: userDefaultsKey),
              var settings = try? JSONDecoder().decode(ProviderSettings.self, from: data)
        else {
            return .default
        }

        // Forward-compat: append any new providers not present in stored settings
        for entry in defaultEntries where !settings.entries.contains(where: { $0.id == entry.id }) {
            settings.entries.append(entry)
        }

        // Remove stored entries for providers that no longer exist
        let knownIds = Set(defaultEntries.map(\.id))
        settings.entries.removeAll { !knownIds.contains($0.id) }

        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }

    /// Human-readable display names for provider IDs.
    static let displayNames: [String: String] = [
        "lrclib": "LRCLIB",
        "musixmatch": "Musixmatch",
        "sodamusic": "Soda Music",
        "netease": "Netease",
    ]

    static func displayName(for id: String) -> String {
        displayNames[id] ?? id
    }
}
