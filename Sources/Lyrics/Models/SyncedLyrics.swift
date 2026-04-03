import Foundation

/// A single time-stamped lyric line.
struct LyricLine: Identifiable, Codable {
    let id: Int // index in the lyrics array
    let time: TimeInterval
    let text: String
    let translation: String?
}

/// Parsed synced lyrics with source attribution.
struct SyncedLyrics: Codable {
    let lines: [LyricLine]
    let source: String // e.g. "lrclib"
    let globalOffset: TimeInterval // user-adjustable offset (seconds)

    /// Find the index of the active line for a given playback position (binary search).
    func lineIndex(at position: TimeInterval) -> Int? {
        let adjusted = position + globalOffset
        // Binary search: find the last line whose time <= adjusted
        var lo = 0
        var hi = lines.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if lines[mid].time <= adjusted {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo > 0 ? lo - 1 : nil
    }
}
