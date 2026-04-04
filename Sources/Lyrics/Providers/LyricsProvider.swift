import Foundation

/// A source that can supply synced lyrics for a given track.
protocol LyricsProvider: Sendable {
    var name: String { get }
    var priority: Int { get } // lower = higher priority
    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics?
    /// Search for multiple lyrics candidates. Providers that support multi-result override this.
    func searchLyrics(for track: TrackInfo, limit: Int) async throws -> [LyricsSearchResult]
}

extension LyricsProvider {
    func searchLyrics(for track: TrackInfo, limit _: Int = 5) async throws -> [LyricsSearchResult] {
        if let lyrics = try await fetchLyrics(for: track) {
            return [LyricsSearchResult(
                provider: name,
                lyrics: lyrics,
                matchInfo: "\(track.title) \u{2014} \(track.artist)",
                score: 15,
                confidence: .prettyHigh
            )]
        }
        return []
    }
}
