import Foundation

/// A single lyrics candidate returned by a provider search, with match scoring.
struct LyricsSearchResult: Identifiable {
    let id = UUID()
    let provider: String
    let lyrics: SyncedLyrics
    let matchInfo: String // "Matched Title — Artist"
    let score: Double // 0–30, from TrackMatcher
    let confidence: TrackMatcher.Confidence
}
