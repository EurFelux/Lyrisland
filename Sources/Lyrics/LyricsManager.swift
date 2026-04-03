import Combine
import Foundation

/// Manages lyric fetching with provider fallback chain and caching.
@MainActor
final class LyricsManager: ObservableObject {
    @Published private(set) var currentLyrics: SyncedLyrics?
    @Published private(set) var isLoading = false
    @Published var userOffset: TimeInterval = 0 // ± seconds, applied on top of globalOffset

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

    /// Providers sorted by priority (lower = tried first).
    private let providers: [LyricsProvider] = [
        LRCLibProvider(), // 0 — open, free, no auth
        MusixmatchProvider(), // 1 — strong for Western music, richsync
        SodaMusicProvider(), // 2 — ByteDance, good for Chinese lyrics
        NeteaseProvider(), // 3 — Netease Cloud Music, strong for Chinese/Asian music
    ]

    /// Two-tier cache (memory + disk) keyed by track ID.
    private let cache = Cache<String, SyncedLyrics>(
        memoryCountLimit: 200,
        namespace: "Lyrics",
        diskLimitBytes: 50 * 1024 * 1024,
        serializer: CodableCacheSerializer<SyncedLyrics>()
    )

    func loadLyrics(for track: TrackInfo) async {
        // Clear stale lyrics immediately so the UI never shows the previous track's lyrics
        currentLyrics = nil

        // Check cache (memory → disk)
        if let cached = await cache.get(track.id) {
            logDebug("Lyrics cache hit for: \(track.title) — \(track.artist)")
            currentLyrics = cached
            return
        }

        logInfo("Loading lyrics for: \(track.title) — \(track.artist)")
        isLoading = true
        defer { isLoading = false }

        // Walk the fallback chain
        for provider in providers.sorted(by: { $0.priority < $1.priority }) {
            do {
                if let lyrics = try await provider.fetchLyrics(for: track) {
                    logInfo("Lyrics found via \(provider.name) for: \(track.title)")
                    await cache.set(lyrics, forKey: track.id)
                    currentLyrics = lyrics
                    return
                }
            } catch {
                logWarning("Provider \(provider.name) failed for \(track.title): \(error.localizedDescription)")
                continue
            }
        }

        // No provider returned lyrics
        logWarning("No lyrics found for: \(track.title) — \(track.artist)")
        currentLyrics = nil
    }

    func clearCache() async {
        await cache.removeAll()
    }
}
