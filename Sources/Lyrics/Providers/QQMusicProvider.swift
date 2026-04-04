import Foundation

/// Fetches lyrics from QQ Music (QQ 音乐).
/// Uses the public web API — no auth required. Huge catalog of Chinese music with translations.
struct QQMusicProvider: LyricsProvider {
    let name = "qqmusic"
    let priority = 4

    private let searchURL = "https://u.y.qq.com/cgi-bin/musicu.fcg"
    private let lyricURL = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        guard let songMid = try await searchTrack(track) else {
            logDebug("[qqmusic] No matching track found")
            return nil
        }
        logDebug("[qqmusic] Matched song MID: \(songMid)")
        return try await fetchSongLyrics(songMid: songMid)
    }

    // MARK: - Search

    private func searchTrack(_ track: TrackInfo) async throws -> String? {
        let scored = try await searchTopCandidates(track, limit: 1)
        return scored.first?.mid
    }

    // MARK: - Multi-result Search

    func searchLyrics(for track: TrackInfo, limit: Int = 5) async throws -> [LyricsSearchResult] {
        let candidates = try await searchTopCandidates(track, limit: limit)
        guard !candidates.isEmpty else { return [] }

        return await withTaskGroup(of: LyricsSearchResult?.self, returning: [LyricsSearchResult].self) { group in
            for candidate in candidates {
                group.addTask {
                    guard let lyrics = try? await fetchSongLyrics(songMid: candidate.mid) else { return nil }
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
        let mid: String
        let matchInfo: String
        let score: Double
        let confidence: TrackMatcher.Confidence
    }

    private func searchTopCandidates(_ track: TrackInfo, limit: Int) async throws -> [ScoredCandidate] {
        let list = try await fetchSearchResults(for: track)
        guard let list else { return [] }

        return list
            .compactMap { song -> ScoredCandidate? in
                guard let mid = song["mid"] as? String,
                      let title = song["title"] as? String else { return nil }

                let singers = (song["singer"] as? [[String: Any]])?
                    .compactMap { $0["name"] as? String }
                    .joined(separator: ", ") ?? ""
                let album = (song["album"] as? [String: Any])?["name"] as? String
                let durationMs = (song["interval"] as? Int).map { $0 * 1000 }

                let candidate = TrackMatcher.Candidate(
                    title: title, artist: singers, album: album, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return ScoredCandidate(
                    mid: mid,
                    matchInfo: "\(title) \u{2014} \(singers)",
                    score: score,
                    confidence: confidence
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    private func fetchSearchResults(for track: TrackInfo) async throws -> [[String: Any]]? {
        guard let url = URL(string: searchURL) else { return nil }

        let query = "\(track.title) \(track.artist)"
        let payload: [String: Any] = [
            "comm": [
                "ct": 19,
                "cv": 1859,
                "uin": "0",
            ],
            "req": [
                "method": "DoSearchForQQMusicDesktop",
                "module": "music.search.SearchCgiService",
                "param": [
                    "num_per_page": 10,
                    "page_num": 1,
                    "query": query,
                    "search_type": 0,
                ],
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let req = json["req"] as? [String: Any],
              let reqData = req["data"] as? [String: Any],
              let body = reqData["body"] as? [String: Any],
              let songList = body["song"] as? [String: Any],
              let list = songList["list"] as? [[String: Any]]
        else {
            return nil
        }

        return list
    }

    // MARK: - Lyrics Fetch

    private func fetchSongLyrics(songMid: String) async throws -> SyncedLyrics? {
        var components = URLComponents(string: lyricURL)!
        components.queryItems = [
            URLQueryItem(name: "songmid", value: songMid),
            URLQueryItem(name: "pcachetime", value: String(Int(Date().timeIntervalSince1970 * 1000))),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "nobase64", value: "1"),
            URLQueryItem(name: "g_tk", value: "5381"),
            URLQueryItem(name: "loginUin", value: "0"),
            URLQueryItem(name: "hostUin", value: "0"),
            URLQueryItem(name: "platform", value: "yqq"),
            URLQueryItem(name: "needNewCode", value: "0"),
        ]

        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://c.y.qq.com/", forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        let jsonData = extractJSON(from: data)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return nil }

        // Decode lyrics — may be Base64 or plain text depending on nobase64 param
        guard let lyricContent = decodeLyricField(json, key: "lyric") else { return nil }

        // Parse translation lyrics if available
        var translationMap: [TimeInterval: String]?
        if let transContent = decodeLyricField(json, key: "trans") {
            translationMap = buildTranslationMap(transContent)
        }

        let lines = LRCParser.parse(lyricContent, translations: translationMap)
        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: name, globalOffset: 0)
    }

    /// Extract the lyric string from the response, handling both Base64 and plain text.
    private func decodeLyricField(_ json: [String: Any], key: String) -> String? {
        guard let value = json[key] as? String, !value.isEmpty else { return nil }

        // If it looks like LRC (starts with [), use as-is
        if value.hasPrefix("[") { return value }

        // Try Base64 decoding
        if let decoded = Data(base64Encoded: value),
           let text = String(data: decoded, encoding: .utf8), !text.isEmpty {
            return text
        }

        return value
    }

    /// Strip JSONP callback wrapper if present, returning raw JSON data.
    static func extractJSON(from data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }

        // Match pattern: callbackName({...})
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let openParen = trimmed.firstIndex(of: "("),
           trimmed.last == ")" || trimmed.hasSuffix(");") {
            let suffix = trimmed.hasSuffix(");") ? 2 : 1
            let jsonStart = trimmed.index(after: openParen)
            let jsonEnd = trimmed.index(trimmed.endIndex, offsetBy: -suffix)
            if jsonStart < jsonEnd {
                let jsonStr = String(trimmed[jsonStart ..< jsonEnd])
                return Data(jsonStr.utf8)
            }
        }

        return data
    }

    private func extractJSON(from data: Data) -> Data {
        QQMusicProvider.extractJSON(from: data)
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
