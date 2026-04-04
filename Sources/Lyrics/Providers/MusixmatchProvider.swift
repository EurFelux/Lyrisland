import Foundation

/// Fetches lyrics from Musixmatch desktop API.
/// Supports line-synced (LRC via subtitle) and word-synced (richsync).
/// Requires a user token obtained once from the token endpoint.
final class MusixmatchProvider: LyricsProvider, @unchecked Sendable {
    let name = "musixmatch"

    private let appId = "web-desktop-app-v1.0"
    private let baseURL = "https://apic-desktop.musixmatch.com/ws/1.1"
    private var userToken: String?
    private let maxCaptchaRetries = 8

    // MARK: - LyricsProvider

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        let token = try await ensureToken()

        // Try macro.subtitles.get which returns richsync + subtitle + plain lyrics
        let durationSec = Int(track.durationSeconds)
        var components = URLComponents(string: "\(baseURL)/macro.subtitles.get")!
        components.queryItems = [
            URLQueryItem(name: "namespace", value: "lyrics_richsynched"),
            URLQueryItem(name: "optional_calls", value: "track.richsync"),
            URLQueryItem(name: "subtitle_format", value: "lrc"),
            URLQueryItem(name: "q_track", value: track.title),
            URLQueryItem(name: "q_artist", value: track.artist),
            URLQueryItem(name: "f_subtitle_length", value: String(durationSec)),
            URLQueryItem(name: "q_duration", value: String(durationSec)),
            URLQueryItem(name: "f_subtitle_length_max_deviation", value: "40"),
            URLQueryItem(name: "usertoken", value: token),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "t", value: String(Int.random(in: 1000 ... 9999))),
        ]

        guard let url = components.url else { return nil }
        let data = try await requestWithRetry(url: url)
        return try parseMacroResponse(data)
    }

    // MARK: - Token Management

    private func ensureToken() async throws -> String {
        if let token = userToken { return token }

        var components = URLComponents(string: "\(baseURL)/token.get")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "t", value: String(Int.random(in: 1000 ... 9999))),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let token = body["user_token"] as? String
        else {
            throw MusixmatchError.tokenFailed
        }

        logDebug("[musixmatch] Token acquired")
        userToken = token
        return token
    }

    // MARK: - Request with captcha/renew retry

    private func requestWithRetry(url: URL) async throws -> Data {
        for attempt in 0 ..< maxCaptchaRetries {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw MusixmatchError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                // Check for status code inside JSON body
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let header = message["header"] as? [String: Any],
                   let statusCode = header["status_code"] as? Int {
                    if statusCode == 401 {
                        let hint = header["hint"] as? String ?? ""
                        if hint == "renew" {
                            logDebug("[musixmatch] Token expired, renewing (attempt \(attempt + 1))")
                            userToken = nil
                            _ = try await ensureToken()
                            continue
                        }
                        if hint == "captcha" {
                            if attempt < maxCaptchaRetries - 1 {
                                logDebug("[musixmatch] Captcha required, retrying (attempt \(attempt + 1))")
                                try await Task.sleep(for: .seconds(1))
                                continue
                            }
                            throw MusixmatchError.captcha
                        }
                    }
                }
                return data
            }

            if httpResponse.statusCode == 401 {
                userToken = nil
                _ = try await ensureToken()
                continue
            }

            throw MusixmatchError.httpError(httpResponse.statusCode)
        }

        throw MusixmatchError.captcha
    }

    // MARK: - Response Parsing

    /// Parse the macro.subtitles.get response.
    /// Fallback order: richsync (word-level) → subtitle (LRC) → plain lyrics.
    private func parseMacroResponse(_ data: Data) throws -> SyncedLyrics? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let macroCalls = body["macro_calls"] as? [String: Any]
        else {
            return nil
        }

        // 1. Try richsync (word-level synced)
        if let richsync = extractRichSync(from: macroCalls) {
            return richsync
        }

        // 2. Try subtitle (LRC line-synced)
        if let subtitle = extractSubtitle(from: macroCalls) {
            return subtitle
        }

        // 3. Try plain lyrics (unsynced — skip, we only want synced)
        return nil
    }

    /// Parse richsync JSON: array of objects with `ts` (start), `te` (end), `x` (text).
    private func extractRichSync(from macroCalls: [String: Any]) -> SyncedLyrics? {
        guard let richsyncGet = macroCalls["track.richsync.get"] as? [String: Any],
              let message = richsyncGet["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let richsync = body["richsync"] as? [String: Any],
              let richsyncBody = richsync["richsync_body"] as? String,
              let bodyData = richsyncBody.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: bodyData) as? [[String: Any]]
        else {
            return nil
        }

        var lines: [LyricLine] = []
        for (index, entry) in entries.enumerated() {
            guard let ts = entry["ts"] as? Double,
                  let x = entry["x"] as? String else { continue }
            guard !x.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            lines.append(LyricLine(id: index, time: ts, text: x, translation: nil))
        }

        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: "musixmatch-richsync", globalOffset: 0)
    }

    /// Parse subtitle body (LRC format string).
    private func extractSubtitle(from macroCalls: [String: Any]) -> SyncedLyrics? {
        guard let subtitlesGet = macroCalls["track.subtitles.get"] as? [String: Any],
              let message = subtitlesGet["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let subtitleList = body["subtitle_list"] as? [[String: Any]],
              let first = subtitleList.first,
              let subtitle = first["subtitle"] as? [String: Any],
              let subtitleBody = subtitle["subtitle_body"] as? String
        else {
            return nil
        }

        let lines = LRCParser.parse(subtitleBody)
        guard !lines.isEmpty else { return nil }
        return SyncedLyrics(lines: lines, source: "musixmatch", globalOffset: 0)
    }
}

// MARK: - Errors

enum MusixmatchError: Error {
    case tokenFailed
    case invalidResponse
    case captcha
    case httpError(Int)
}
