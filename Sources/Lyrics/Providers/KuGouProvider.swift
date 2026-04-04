import Foundation
import zlib

/// Fetches lyrics from KuGou Music (酷狗音乐).
/// Uses the public web API — no auth required. Decrypts KRC-format encrypted lyrics.
struct KuGouProvider: LyricsProvider {
    let name = "kugou"
    let priority = 5

    private let searchURL = "https://mobilecdn.kugou.com/api/v3/search/song"
    private let lyricsSearchURL = "https://lyrics.kugou.com/search"
    private let lyricsDownloadURL = "https://lyrics.kugou.com/download"

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        guard let candidate = try await searchTrack(track) else {
            logDebug("[kugou] No matching track found")
            return nil
        }
        logDebug("[kugou] Matched track: \(candidate.matchInfo)")
        return try await fetchBestLyrics(hash: candidate.hash, durationMs: candidate.durationMs)
    }

    // MARK: - Song Search

    private struct SongCandidate {
        let hash: String
        let durationMs: Int
        let matchInfo: String
        let score: Double
        let confidence: TrackMatcher.Confidence
    }

    private func searchTrack(_ track: TrackInfo) async throws -> SongCandidate? {
        let candidates = try await searchTopCandidates(track, limit: 1)
        return candidates.first
    }

    // MARK: - Multi-result Search

    func searchLyrics(for track: TrackInfo, limit: Int = 5) async throws -> [LyricsSearchResult] {
        let candidates = try await searchTopCandidates(track, limit: limit)
        guard !candidates.isEmpty else { return [] }

        return await withTaskGroup(of: LyricsSearchResult?.self, returning: [LyricsSearchResult].self) { group in
            for candidate in candidates {
                group.addTask {
                    guard let lyrics = try? await fetchBestLyrics(
                        hash: candidate.hash, durationMs: candidate.durationMs
                    ) else { return nil }
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

    private func searchTopCandidates(_ track: TrackInfo, limit: Int) async throws -> [SongCandidate] {
        let query = "\(track.title) \(track.artist)"
        var components = URLComponents(string: searchURL)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "pagesize", value: "20"),
            URLQueryItem(name: "showtype", value: "1"),
        ]

        guard let url = components.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let info = dataObj["info"] as? [[String: Any]]
        else {
            return []
        }

        return info
            .compactMap { song -> SongCandidate? in
                guard let hash = song["hash"] as? String,
                      let songName = song["songname"] as? String else { return nil }

                let singerName = song["singername"] as? String ?? ""
                let albumName = song["album_name"] as? String
                let durationSec = song["duration"] as? Int
                let durationMs = durationSec.map { $0 * 1000 }

                let candidate = TrackMatcher.Candidate(
                    title: songName, artist: singerName, album: albumName, durationMs: durationMs
                )
                let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
                guard confidence >= .low else { return nil }
                return SongCandidate(
                    hash: hash,
                    durationMs: durationMs ?? track.durationMs,
                    matchInfo: "\(songName) \u{2014} \(singerName)",
                    score: score,
                    confidence: confidence
                )
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Lyrics Fetch

    private func fetchBestLyrics(hash: String, durationMs: Int) async throws -> SyncedLyrics? {
        // Step 1: Search for lyrics candidates by hash
        var components = URLComponents(string: lyricsSearchURL)!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "man", value: "yes"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "hash", value: hash),
            URLQueryItem(name: "keyword", value: ""),
            URLQueryItem(name: "duration", value: String(durationMs)),
        ]

        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let best = candidates.first,
              let id = best["id"] as? String ?? (best["id"] as? Int).map(String.init),
              let accessKey = best["accesskey"] as? String
        else {
            return nil
        }

        // Step 2: Download encrypted KRC lyrics
        return try await downloadLyrics(id: id, accessKey: accessKey)
    }

    private func downloadLyrics(id: String, accessKey: String) async throws -> SyncedLyrics? {
        var components = URLComponents(string: lyricsDownloadURL)!
        components.queryItems = [
            URLQueryItem(name: "ver", value: "1"),
            URLQueryItem(name: "client", value: "pc"),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "accesskey", value: accessKey),
            URLQueryItem(name: "fmt", value: "krc"),
            URLQueryItem(name: "charset", value: "utf8"),
        ]

        guard let url = components.url else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? String
        else {
            return nil
        }

        guard let decrypted = KRCDecrypter.decrypt(base64Encoded: content) else {
            logDebug("[kugou] Failed to decrypt KRC lyrics")
            return nil
        }

        // Parse translations from [language:...] tag if present
        let translationMap = KRCParser.parseTranslations(decrypted)

        let lines = KRCParser.parse(decrypted, translations: translationMap)
        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: name, globalOffset: 0)
    }
}

// MARK: - KRC Decrypter

enum KRCDecrypter {
    /// XOR key used to decrypt KRC data.
    static let xorKey: [UInt8] = [
        0x40, 0x47, 0x61, 0x77, 0x5E, 0x32, 0x74, 0x47,
        0x51, 0x36, 0x31, 0x2D, 0xCE, 0xD2, 0x6E, 0x69,
    ]

    /// Decrypt a Base64-encoded KRC string.
    /// Steps: Base64 decode → skip 4 header bytes → XOR → zlib inflate.
    static func decrypt(base64Encoded: String) -> String? {
        guard let raw = Data(base64Encoded: base64Encoded), raw.count > 4 else { return nil }

        // Skip 4-byte header
        let encrypted = raw.dropFirst(4)

        // XOR with cyclic key
        var xored = [UInt8](repeating: 0, count: encrypted.count)
        for (i, byte) in encrypted.enumerated() {
            xored[i] = byte ^ xorKey[i % xorKey.count]
        }

        // Inflate (raw DEFLATE, no zlib/gzip header)
        guard let decompressed = inflate(Data(xored)) else { return nil }

        var text = String(data: decompressed, encoding: .utf8) ?? ""
        // Skip leading BOM or garbage character
        if !text.isEmpty, let first = text.unicodeScalars.first,
           first == "\u{FEFF}" {
            text = String(text.dropFirst())
        }
        return text.isEmpty ? nil : text
    }

    /// Raw DEFLATE inflate (no zlib header).
    private static func inflate(_ data: Data) -> Data? {
        var input = [UInt8](data)

        // Try raw deflate first, then zlib-wrapped
        for wbits: Int32 in [-MAX_WBITS, MAX_WBITS + 32] {
            var stream = z_stream()
            guard inflateInit2_(&stream, wbits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                continue
            }
            defer { inflateEnd(&stream) }

            let result: Data? = input.withUnsafeMutableBufferPointer { inputPtr in
                let outputSize = data.count * 10
                var output = [UInt8](repeating: 0, count: outputSize)

                return output.withUnsafeMutableBufferPointer { outputPtr in
                    stream.next_in = inputPtr.baseAddress
                    stream.avail_in = UInt32(inputPtr.count)
                    stream.next_out = outputPtr.baseAddress
                    stream.avail_out = UInt32(outputSize)

                    let status = zlib.inflate(&stream, Z_FINISH)
                    if status == Z_STREAM_END || status == Z_OK {
                        let count = outputSize - Int(stream.avail_out)
                        return Data(outputPtr.prefix(count))
                    }
                    return nil
                }
            }
            if let result { return result }
        }
        return nil
    }
}

// MARK: - KRC Parser

enum KRCParser {
    /// Parse KRC text into `LyricLine` array.
    /// KRC lines look like: `[startMs,durationMs]<0,300,0>word1<300,200,0>word2`
    static func parse(_ krc: String, translations: [TimeInterval: String]? = nil) -> [LyricLine] {
        let linePattern = #"^\[(\d+),(\d+)\](.*)$"#
        guard let lineRegex = try? NSRegularExpression(pattern: linePattern, options: .anchorsMatchLines) else {
            return []
        }
        // Matches inline syllable tags: <offset,duration,pitch>text
        let syllablePattern = #"<\d+,\d+,\d+>"#
        guard let syllableRegex = try? NSRegularExpression(pattern: syllablePattern) else { return [] }

        var lines: [LyricLine] = []

        for line in krc.components(separatedBy: .newlines) {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = lineRegex.firstMatch(in: line, range: range) else { continue }

            let startMs = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
            let content = nsLine.substring(with: match.range(at: 3))

            // Strip syllable timing tags to get plain text
            let text = syllableRegex.stringByReplacingMatches(
                in: content, range: NSRange(location: 0, length: content.utf16.count),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)

            guard !text.isEmpty else { continue }

            let time = startMs / 1000.0
            let translation = translations?[time]
            lines.append(LyricLine(id: lines.count, time: time, text: text, translation: translation))
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// Extract translations from `[language:BASE64_DATA]` tag in KRC.
    static func parseTranslations(_ krc: String) -> [TimeInterval: String]? {
        let pattern = #"\[language:([\w+/=]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: krc, range: NSRange(krc.startIndex..., in: krc)),
              let range = Range(match.range(at: 1), in: krc)
        else {
            return nil
        }

        let base64 = String(krc[range])
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["content"] as? [[String: Any]]
        else {
            return nil
        }

        // Find Chinese translation (type 1) first, then fall back to any type
        let translationContent = contents.first { ($0["type"] as? Int) == 1 }
            ?? contents.first

        guard let lyricContent = translationContent?["lyricContent"] as? [[[String: Any]]] else { return nil }

        return parseTranslationsByOrder(lyricContent: lyricContent, krc: krc)
    }

    /// Match translations to main lyrics by line order.
    private static func parseTranslationsByOrder(
        lyricContent: [[[String: Any]]],
        krc: String
    ) -> [TimeInterval: String]? {
        // Extract main lyric line timestamps in order
        let linePattern = #"^\[(\d+),(\d+)\]"#
        guard let lineRegex = try? NSRegularExpression(pattern: linePattern, options: .anchorsMatchLines) else {
            return nil
        }

        var timestamps: [TimeInterval] = []
        for line in krc.components(separatedBy: .newlines) {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            if let match = lineRegex.firstMatch(in: line, range: range) {
                let startMs = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                timestamps.append(startMs / 1000.0)
            }
        }

        var map: [TimeInterval: String] = [:]
        for (index, lineSegments) in lyricContent.enumerated() {
            guard index < timestamps.count else { break }
            let text = lineSegments.compactMap { $0["lineLyric"] as? String }.joined()
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            map[timestamps[index]] = trimmed
        }

        return map.isEmpty ? nil : map
    }
}
