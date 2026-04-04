import Foundation

/// A source that can supply synced lyrics for a given track.
protocol LyricsProvider: Sendable {
    var name: String { get }
    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics?
    /// Search for multiple lyrics candidates. Providers that support multi-result override this.
    func searchLyrics(for track: TrackInfo, limit: Int) async throws -> [LyricsSearchResult]
}

extension LyricsProvider {
    /// Default `searchLyrics` wraps `fetchLyrics`. Since providers using this default
    /// perform exact matching via their API, we score the result against the target track
    /// metadata to derive a realistic TrackMatcher score rather than a hardcoded value.
    func searchLyrics(for track: TrackInfo, limit _: Int = 5) async throws -> [LyricsSearchResult] {
        if let lyrics = try await fetchLyrics(for: track) {
            let candidate = TrackMatcher.Candidate(
                title: track.title,
                artist: track.artist,
                album: track.album,
                durationMs: track.durationMs
            )
            let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
            return [LyricsSearchResult(
                provider: name,
                lyrics: lyrics,
                matchInfo: "\(track.title) \u{2014} \(track.artist)",
                score: score,
                confidence: confidence
            )]
        }
        return []
    }
}
