import Foundation

/// Fetches synced lyrics from LRCLIB (https://lrclib.net).
/// Free, open API — no auth required.
struct LRCLibProvider: LyricsProvider {
    let name = "lrclib"
    let priority = 0

    private let baseURL = "https://lrclib.net/api"

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        // Try exact match first, then search fallback
        logDebug("[lrclib] Trying exact match for: \(track.title)")
        if let lyrics = try await fetchExact(track: track) {
            logDebug("[lrclib] Exact match found")
            return lyrics
        }
        logDebug("[lrclib] Exact match failed, trying search fallback")
        return try await fetchSearch(track: track)
    }

    // MARK: - Exact match by metadata

    private func fetchExact(track: TrackInfo) async throws -> SyncedLyrics? {
        var components = URLComponents(string: "\(baseURL)/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.durationSeconds))),
        ]

        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            return nil
        }

        return try parseLRCLibResponse(data)
    }

    // MARK: - Search fallback

    private func fetchSearch(track: TrackInfo) async throws -> SyncedLyrics? {
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.title) \(track.artist)"),
        ]

        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            return nil
        }

        guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = results.first,
              let resultData = try? JSONSerialization.data(withJSONObject: first)
        else {
            return nil
        }

        return try parseLRCLibResponse(resultData)
    }

    // MARK: - Response Parsing

    private func parseLRCLibResponse(_ data: Data) throws -> SyncedLyrics? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let syncedLyrics = json["syncedLyrics"] as? String
        else {
            return nil
        }

        let lines = LRCParser.parse(syncedLyrics)
        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: name, globalOffset: 0)
    }
}
