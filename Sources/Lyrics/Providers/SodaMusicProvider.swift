import Foundation

/// Fetches lyrics from Soda Music / Qishui (汽水音乐, ByteDance).
/// Simple REST API, no auth required. Good for Chinese lyrics.
struct SodaMusicProvider: LyricsProvider {
    let name = "sodamusic"

    private let searchURL = "https://api.qishui.com/luna/pc/search/track"
    private let trackURL = "https://api.qishui.com/luna/pc/track_v2"

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        guard let trackId = try await searchTrack(track) else {
            logDebug("[sodamusic] No matching track found")
            return nil
        }
        logDebug("[sodamusic] Matched track ID: \(trackId)")
        return try await fetchTrackLyrics(trackId: trackId)
    }

    // MARK: - Search

    private func searchTrack(_ track: TrackInfo) async throws -> String? {
        var components = URLComponents(string: searchURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.title) \(track.artist)"),
            URLQueryItem(name: "src", value: ""),
            URLQueryItem(name: "cursor", value: "0"),
            URLQueryItem(name: "count", value: "10"),
        ]

        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let tracks = dataObj["track_list"] as? [[String: Any]]
        else {
            return nil
        }

        // Score candidates with TrackMatcher and pick the best
        let scored = tracks
            .compactMap { item -> (id: String, score: Double)? in
                guard let id = item["id"] as? Int,
                      let title = item["title"] as? String,
                      let artist = item["artist"] as? String else { return nil }
                let album = item["album_title"] as? String
                let durationMs = (item["duration"] as? Int).map { $0 * 1000 }

                let candidate = TrackMatcher.Candidate(
                    title: title, artist: artist, album: album, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return (id: String(id), score: score)
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
                    guard let lyrics = try? await fetchTrackLyrics(trackId: candidate.id) else { return nil }
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
        let id: String
        let matchInfo: String
        let score: Double
        let confidence: TrackMatcher.Confidence
    }

    private func searchTopCandidates(_ track: TrackInfo, limit: Int) async throws -> [ScoredCandidate] {
        var components = URLComponents(string: searchURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(track.title) \(track.artist)"),
            URLQueryItem(name: "src", value: ""),
            URLQueryItem(name: "cursor", value: "0"),
            URLQueryItem(name: "count", value: "10"),
        ]

        guard let url = components.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let tracks = dataObj["track_list"] as? [[String: Any]]
        else {
            return []
        }

        return tracks
            .compactMap { item -> ScoredCandidate? in
                guard let id = item["id"] as? Int,
                      let title = item["title"] as? String,
                      let artist = item["artist"] as? String else { return nil }
                let album = item["album_title"] as? String
                let durationMs = (item["duration"] as? Int).map { $0 * 1000 }

                let candidate = TrackMatcher.Candidate(
                    title: title, artist: artist, album: album, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return ScoredCandidate(
                    id: String(id),
                    matchInfo: "\(title) \u{2014} \(artist)",
                    score: score,
                    confidence: confidence
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Lyrics Fetch

    private func fetchTrackLyrics(trackId: String) async throws -> SyncedLyrics? {
        guard let url = URL(string: trackURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("track_id=\(trackId)&media_type=track&queue_type=".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let trackInfo = dataObj["track_info"] as? [String: Any],
              let lyric = trackInfo["lyric"] as? [String: Any],
              let content = lyric["content"] as? String
        else {
            return nil
        }

        // Parse translations if available
        var translationMap: [TimeInterval: String]?
        if let langTranslations = lyric["lang_translations"] as? [String: Any] {
            // Try Chinese first, then any available
            let preferredKeys = ["zh", "zh-Hans", "en"]
            let chosenKey = preferredKeys.first(where: { langTranslations[$0] != nil })
                ?? langTranslations.keys.first

            if let key = chosenKey,
               let translationContent = langTranslations[key] as? String {
                translationMap = buildTranslationMap(translationContent)
            }
        }

        let lines = LRCParser.parse(content, translations: translationMap)
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
