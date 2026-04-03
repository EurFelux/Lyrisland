import Foundation
@testable import Lyrisland
import Testing

struct ProviderSettingsTests {
    /// Create an isolated UserDefaults suite for each test to avoid side effects.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "test-\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("default has all four providers enabled in correct order")
    func defaultOrder() {
        let settings = ProviderSettings.default
        #expect(settings.entries.count == 4)
        #expect(settings.entries[0].id == "lrclib")
        #expect(settings.entries[1].id == "musixmatch")
        #expect(settings.entries[2].id == "sodamusic")
        #expect(settings.entries[3].id == "netease")
        for entry in settings.entries {
            #expect(entry.isEnabled)
        }
    }

    @Test("load returns default when UserDefaults key is absent")
    func loadMissingKey() {
        let defaults = makeDefaults()
        let settings = ProviderSettings.load(from: defaults)
        #expect(settings == .default)
    }

    @Test("save and load round-trip preserves order and enabled state")
    func saveAndLoad() {
        let defaults = makeDefaults()
        var settings = ProviderSettings.default
        // Reorder: move netease to first, disable musixmatch
        settings.entries = [
            ProviderEntry(id: "netease", isEnabled: true),
            ProviderEntry(id: "lrclib", isEnabled: true),
            ProviderEntry(id: "musixmatch", isEnabled: false),
            ProviderEntry(id: "sodamusic", isEnabled: true),
        ]
        settings.save(to: defaults)

        let loaded = ProviderSettings.load(from: defaults)
        #expect(loaded.entries.count == 4)
        #expect(loaded.entries[0].id == "netease")
        #expect(loaded.entries[2].isEnabled == false)
    }

    @Test("load merges new providers not present in stored settings")
    func forwardCompatMerge() {
        let defaults = makeDefaults()
        // Simulate stored settings with only 2 providers (as if from an older version)
        let old = ProviderSettings(entries: [
            ProviderEntry(id: "lrclib", isEnabled: true),
            ProviderEntry(id: "musixmatch", isEnabled: false),
        ])
        old.save(to: defaults)

        let loaded = ProviderSettings.load(from: defaults)
        #expect(loaded.entries.count == 4)
        // Original entries preserved in order
        #expect(loaded.entries[0].id == "lrclib")
        #expect(loaded.entries[1].id == "musixmatch")
        #expect(loaded.entries[1].isEnabled == false)
        // New providers appended at end with default enabled state
        #expect(loaded.entries[2].id == "sodamusic")
        #expect(loaded.entries[2].isEnabled == true)
        #expect(loaded.entries[3].id == "netease")
        #expect(loaded.entries[3].isEnabled == true)
    }

    @Test("load removes providers that no longer exist")
    func removesObsoleteProviders() {
        let defaults = makeDefaults()
        let old = ProviderSettings(entries: [
            ProviderEntry(id: "lrclib", isEnabled: true),
            ProviderEntry(id: "obsolete_provider", isEnabled: true),
            ProviderEntry(id: "musixmatch", isEnabled: true),
        ])
        old.save(to: defaults)

        let loaded = ProviderSettings.load(from: defaults)
        #expect(!loaded.entries.contains { $0.id == "obsolete_provider" })
        #expect(loaded.entries.count == 4)
    }
}
