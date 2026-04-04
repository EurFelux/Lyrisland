import Foundation

/// Fetches lyrics from Netease Cloud Music (网易云音乐).
/// Uses the public web API — no auth required. Excellent coverage for Chinese and Asian music.
struct NeteaseProvider: LyricsProvider {
    let name = "netease"

    private let searchURL = "https://music.163.com/api/search/get/web"
    private let lyricURL = "https://music.163.com/api/song/lyric"

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        guard let songId = try await searchTrack(track) else {
            logDebug("[netease] No matching track found")
            return nil
        }
        logDebug("[netease] Matched song ID: \(songId)")
        return try await fetchSongLyrics(songId: songId)
    }

    // MARK: - Search

    private func searchTrack(_ track: TrackInfo) async throws -> Int? {
        guard let url = URL(string: searchURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let query = "\(track.title) \(track.artist)"
        let body = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&offset=0&limit=10"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]]
        else {
            return nil
        }

        // Score candidates with TrackMatcher and pick the best
        let scored = songs
            .compactMap { song -> (id: Int, score: Double)? in
                guard let id = song["id"] as? Int,
                      let title = song["name"] as? String else { return nil }

                let artists = (song["artists"] as? [[String: Any]])?
                    .compactMap { $0["name"] as? String }
                    .joined(separator: ", ") ?? ""
                let album = (song["album"] as? [String: Any])?["name"] as? String
                let durationMs = song["duration"] as? Int

                let candidate = TrackMatcher.Candidate(
                    title: title, artist: artists, album: album, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return (id: id, score: score)
            }
            .max(by: { $0.score < $1.score })

        return scored?.id
    }

    // MARK: - Multi-result Search

    func searchLyrics(for track: TrackInfo, limit: Int = 5) async throws -> [LyricsSearchResult] {
        let candidates = try await searchTopCandidates(track, limit: limit)
        guard !candidates.isEmpty else { return [] }

        return await withTaskGroup(of: LyricsSearchResult?.self, returning: [LyricsSearchResult].self) { group in
            for candidate in candidates {
                group.addTask {
                    guard let lyrics = try? await fetchSongLyrics(songId: candidate.id) else { return nil }
                    return LyricsSearchResult(
                        provider: name,
                        lyrics: lyrics,
                        matchInfo: candidate.matchInfo,
                        score: candidate.score,
                        confidence: candidate.confidence
                    )
                }
            }
            var results: [LyricsSearchResult] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results.sorted { $0.score > $1.score }
        }
    }

    private struct ScoredCandidate {
        let id: Int
        let matchInfo: String
        let score: Double
        let confidence: TrackMatcher.Confidence
    }

    private func searchTopCandidates(_ track: TrackInfo, limit: Int) async throws -> [ScoredCandidate] {
        guard let url = URL(string: searchURL) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let query = "\(track.title) \(track.artist)"
        let body = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=1&offset=0&limit=10"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]]
        else {
            return []
        }

        return songs
            .compactMap { song -> ScoredCandidate? in
                guard let id = song["id"] as? Int,
                      let title = song["name"] as? String else { return nil }

                let artists = (song["artists"] as? [[String: Any]])?
                    .compactMap { $0["name"] as? String }
                    .joined(separator: ", ") ?? ""
                let album = (song["album"] as? [String: Any])?["name"] as? String
                let durationMs = song["duration"] as? Int

                let candidate = TrackMatcher.Candidate(
                    title: title, artist: artists, album: album, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return ScoredCandidate(
                    id: id,
                    matchInfo: "\(title) \u{2014} \(artists)",
                    score: score,
                    confidence: confidence
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Lyrics Fetch

    private func fetchSongLyrics(songId: Int) async throws -> SyncedLyrics? {
        var components = URLComponents(string: lyricURL)!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(songId)),
            URLQueryItem(name: "lv", value: "-1"),
            URLQueryItem(name: "tv", value: "-1"),
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lrc = json["lrc"] as? [String: Any],
              let lyricContent = lrc["lyric"] as? String
        else {
            return nil
        }

        // Parse translation lyrics if available
        var translationMap: [TimeInterval: String]?
        if let tlyric = json["tlyric"] as? [String: Any],
           let transContent = tlyric["lyric"] as? String,
           !transContent.isEmpty {
            translationMap = buildTranslationMap(transContent)
        }

        let lines = LRCParser.parse(lyricContent, translations: translationMap)
        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: name, globalOffset: 0)
    }

    /// Parse a parallel LRC translation string into a time→text map.
    private func buildTranslationMap(_ lrc: String) -> [TimeInterval: String] {
        let parsed = LRCParser.parse(lrc)
        var map: [TimeInterval: String] = [:]
        for line in parsed {
            map[line.time] = line.text
        }
        return map
    }
}
