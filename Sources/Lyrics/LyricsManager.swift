import Combine
import Foundation

/// Manages lyric fetching with concurrent best-score selection and caching.
@MainActor
final class LyricsManager: ObservableObject {
    @Published private(set) var currentLyrics: SyncedLyrics?
    @Published private(set) var isLoading = false
    @Published var userOffset: TimeInterval = 0 // ± seconds, applied on top of globalOffset

    /// The track currently loaded (or being loaded), kept for provider switching.
    private(set) var currentTrack: TrackInfo?

    /// Adjust user offset by a delta (e.g. +0.5 or -0.5 seconds).
    func adjustOffset(by delta: TimeInterval) {
        userOffset += delta
        // Rebuild current lyrics with updated offset
        if let lyrics = currentLyrics {
            currentLyrics = SyncedLyrics(
                lines: lyrics.lines,
                source: lyrics.source,
                globalOffset: lyrics.globalOffset + delta
            )
        }
    }

    func resetOffset() {
        if let lyrics = currentLyrics {
            currentLyrics = SyncedLyrics(
                lines: lyrics.lines,
                source: lyrics.source,
                globalOffset: lyrics.globalOffset - userOffset
            )
        }
        userOffset = 0
    }

    /// User-configured provider order and enable/disable state.
    @Published var providerSettings: ProviderSettings

    /// All available providers. Array order breaks score ties in `bestResult`; settings only enable or disable.
    private let allProviders: [LyricsProvider] = [
        LRCLibProvider(),
        MusixmatchProvider(),
        SodaMusicProvider(),
        NeteaseProvider(),
        QQMusicProvider(),
        KuGouProvider(),
    ]

    /// Enabled providers in registry order. All are fetched concurrently; the order only breaks score ties.
    private var enabledProviders: [LyricsProvider] {
        let enabledIds = Set(providerSettings.entries.filter(\.isEnabled).map(\.id))
        return allProviders.filter { enabledIds.contains($0.name) }
    }

    init() {
        providerSettings = ProviderSettings.load()
        Self.removeLegacyLyricsCache()
    }

    func updateProviderSettings(_ settings: ProviderSettings) {
        providerSettings = settings
    }

    /// Two-tier cache (memory + disk) keyed by track ID.
    private let cache = Cache<String, SyncedLyrics>(
        memoryCountLimit: 200,
        namespace: "Lyrics-v2",
        diskLimitBytes: 50 * 1024 * 1024,
        serializer: CodableCacheSerializer<SyncedLyrics>()
    )

    /// Earlier builds scored every Musixmatch result 30.0, so lyrics cached under the old "Lyrics"
    /// namespace may be the Musixmatch decoy for any track. They cannot be told apart, so drop them.
    private static func removeLegacyLyricsCache() {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let legacy = caches
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Lyrisland")
            .appendingPathComponent("Lyrics")
        try? FileManager.default.removeItem(at: legacy)
    }

    func loadLyrics(for track: TrackInfo) async {
        currentTrack = track
        // Clear stale lyrics immediately so the UI never shows the previous track's lyrics
        currentLyrics = nil

        // Check cache (memory -> disk)
        if let cached = await cache.get(track.id) {
            logDebug("Lyrics cache hit for: \(track.title) — \(track.artist)")
            currentLyrics = cached
            return
        }

        logInfo("Loading lyrics for: \(track.title) — \(track.artist)")
        isLoading = true
        defer { isLoading = false }

        // If user has a per-track override, try that provider first
        if let overrideProvider = TrackLyricsOverride.preferredProvider(for: track.id),
           let provider = allProviders.first(where: { $0.name == overrideProvider }) {
            do {
                if let lyrics = try await provider.fetchLyrics(for: track) {
                    logInfo("Override provider \(provider.name) found lyrics for: \(track.title)")
                    await cache.set(lyrics, forKey: track.id)
                    currentLyrics = lyrics
                    return
                }
            } catch {
                logWarning("Override provider \(provider.name) failed: \(error.localizedDescription)")
            }
        }

        // Fetch from all enabled providers concurrently; pick the best score
        let best = await bestResult(for: track, from: enabledProviders)
        if let best {
            logInfo("Best lyrics via \(best.provider) (score \(String(format: "%.1f", best.score))) for: \(track.title)")
            await cache.set(best.lyrics, forKey: track.id)
            currentLyrics = best.lyrics
        } else {
            logWarning("No lyrics found for: \(track.title) — \(track.artist)")
            currentLyrics = nil
        }
    }

    // MARK: - Concurrent Best-Score Selection

    /// Search all given providers concurrently and return the single best-scoring result.
    private func bestResult(
        for track: TrackInfo,
        from providers: [LyricsProvider]
    ) async -> LyricsSearchResult? {
        let providerOrder = Dictionary(uniqueKeysWithValues: providers.enumerated().map { ($0.element.name, $0.offset) })
        return await withTaskGroup(of: LyricsSearchResult?.self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let results = try await provider.searchLyrics(for: track, limit: 1)
                        return results.first
                    } catch {
                        logWarning("Provider \(provider.name) failed for \(track.title): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            var best: LyricsSearchResult?
            for await result in group {
                guard let result else { continue }
                if Self.shouldReplaceBest(result, current: best, providerOrder: providerOrder) {
                    best = result
                }
            }
            return best
        }
    }

    nonisolated static func shouldReplaceBest(
        _ candidate: LyricsSearchResult,
        current: LyricsSearchResult?,
        providerOrder: [String: Int]
    ) -> Bool {
        guard let current else { return true }
        if candidate.score != current.score { return candidate.score > current.score }
        return (providerOrder[candidate.provider] ?? .max) < (providerOrder[current.provider] ?? .max)
    }

    // MARK: - Lyrics Picker

    /// Kick off parallel searches across all providers. Returns ProviderResult objects
    /// whose `status` updates reactively as results arrive.
    /// Intentionally queries all providers (including disabled ones) to maximise the
    /// chance of finding the correct lyrics for the user.
    func fetchFromAllProviders(for track: TrackInfo) -> [ProviderResult] {
        let results = allProviders.map { provider in
            ProviderResult(id: provider.name, displayName: ProviderSettings.displayName(for: provider.name))
        }
        for (provider, result) in zip(allProviders, results) {
            Task {
                do {
                    let searchResults = try await provider.searchLyrics(for: track, limit: 5)
                    result.status = searchResults.isEmpty ? .notFound : .found(searchResults)
                } catch {
                    result.status = .error(error.localizedDescription)
                }
            }
        }
        return results
    }

    /// Apply user-selected lyrics: update current display, cache, and per-track override.
    func applySelectedLyrics(_ lyrics: SyncedLyrics, fromProvider provider: String) async {
        guard let track = currentTrack else { return }
        currentLyrics = lyrics
        await cache.set(lyrics, forKey: track.id)
        TrackLyricsOverride.setPreferredProvider(provider, for: track.id)
        logInfo("User selected lyrics from \(provider) for: \(track.title)")
    }

    func clearCache() async {
        await cache.removeAll()
    }
}
