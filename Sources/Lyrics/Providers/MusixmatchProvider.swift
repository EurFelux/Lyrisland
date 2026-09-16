import Foundation

/// Where the Musixmatch user token is kept between launches.
protocol MusixmatchTokenStore: AnyObject {
    var token: String? { get set }
    /// When token.get last refused to mint a token, so requests can back off.
    var refusedAt: Date? { get set }
}

/// Token store backed by `UserDefaults`.
final class UserDefaultsMusixmatchTokenStore: MusixmatchTokenStore {
    private let defaults: UserDefaults
    private let tokenKey = "musixmatch.userToken"
    private let refusedAtKey = "musixmatch.tokenRefusedAt"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set { set(newValue, forKey: tokenKey) }
    }

    var refusedAt: Date? {
        get { defaults.object(forKey: refusedAtKey) as? Date }
        set { set(newValue, forKey: refusedAtKey) }
    }

    private func set(_ value: Any?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Fetches lyrics from the Musixmatch API using the Android player client identity.
/// Supports line-synced (LRC via subtitle) and word-synced (richsync).
/// Requires a user token obtained once from the token endpoint.
///
/// The desktop identity (`apic-desktop.musixmatch.com`, `web-desktop-app-v1.0`) is retired:
/// its token.get only issues an all-zero token, and every query with it returns the same decoy track.
///
/// token.get answers 401 "captcha" to all but the occasional request from an IP, while a minted
/// token keeps working for at least a day, so the token is persisted and reused across launches
/// and a refused request backs off instead of asking again on the next track change.
final class MusixmatchProvider: LyricsProvider, @unchecked Sendable {
    let name = "musixmatch"

    private let appId = "android-player-v1.0"
    private let baseURL = "https://apic.musixmatch.com/ws/1.1"
    private var userToken: String?
    private let maxCaptchaRetries = 8
    private let tokenStore: MusixmatchTokenStore
    /// How long to wait before asking token.get again after it refused to mint a token.
    private let tokenRetryInterval: TimeInterval = 30 * 60

    init(tokenStore: MusixmatchTokenStore = UserDefaultsMusixmatchTokenStore()) {
        self.tokenStore = tokenStore
        if let stored = tokenStore.token, Self.isUsableToken(stored) {
            userToken = stored
        }
    }

    // MARK: - LyricsProvider

    func fetchLyrics(for track: TrackInfo) async throws -> SyncedLyrics? {
        try await searchLyrics(for: track, limit: 1).first?.lyrics
    }

    func searchLyrics(for track: TrackInfo, limit _: Int = 5) async throws -> [LyricsSearchResult] {
        // Try macro.subtitles.get which returns richsync + subtitle + plain lyrics
        let durationSec = Int(track.durationSeconds)
        let queryItems = [
            URLQueryItem(name: "namespace", value: "lyrics_richsynched"),
            URLQueryItem(name: "optional_calls", value: "track.richsync"),
            URLQueryItem(name: "subtitle_format", value: "lrc"),
            URLQueryItem(name: "q_track", value: track.title),
            URLQueryItem(name: "q_artist", value: track.artist),
            URLQueryItem(name: "f_subtitle_length", value: String(durationSec)),
            URLQueryItem(name: "q_duration", value: String(durationSec)),
            URLQueryItem(name: "f_subtitle_length_max_deviation", value: "40"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "t", value: String(Int.random(in: 1000 ... 9999))),
        ]

        let data = try await requestWithRetry(path: "macro.subtitles.get", queryItems: queryItems)
        return try parseMacroResponse(data, for: track).map { [$0] } ?? []
    }

    // MARK: - Token Management

    private func ensureToken() async throws -> String {
        if let token = userToken { return token }

        guard Self.shouldRequestToken(
            lastRefusal: tokenStore.refusedAt, now: Date(), retryInterval: tokenRetryInterval
        ) else {
            logDebug("[musixmatch] Skipping token request; token.get refused one \(Int(tokenRetryInterval / 60)) min ago or less")
            throw MusixmatchError.tokenFailed
        }

        var components = URLComponents(string: "\(baseURL)/token.get")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: appId),
            URLQueryItem(name: "t", value: String(Int.random(in: 1000 ... 9999))),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any]
        else {
            throw MusixmatchError.tokenFailed
        }
        guard let body = message["body"] as? [String: Any],
              let token = body["user_token"] as? String
        else {
            // token.get answers 401 with hint "captcha" when this IP has requested too many tokens.
            let header = message["header"] as? [String: Any]
            let status = header?["status_code"] as? Int ?? 0
            let hint = header?["hint"] as? String ?? ""
            logWarning("[musixmatch] Token request refused: status \(status), hint \(hint)")
            tokenStore.refusedAt = Date()
            throw MusixmatchError.tokenFailed
        }
        guard Self.isUsableToken(token) else {
            logWarning("[musixmatch] Received a placeholder token; the client identity may be retired")
            tokenStore.refusedAt = Date()
            throw MusixmatchError.tokenFailed
        }

        logDebug("[musixmatch] Token acquired")
        userToken = token
        tokenStore.token = token
        tokenStore.refusedAt = nil
        return token
    }

    /// The token currently in use, restored from the token store at init. Exposed for tests.
    var currentToken: String? {
        userToken
    }

    /// Forget the current token so the next request mints a new one.
    private func discardToken() {
        userToken = nil
        tokenStore.token = nil
    }

    /// token.get is rate limited per IP, so wait out `retryInterval` after it refused to mint a token.
    static func shouldRequestToken(lastRefusal: Date?, now: Date, retryInterval: TimeInterval) -> Bool {
        guard let lastRefusal else { return true }
        let elapsed = now.timeIntervalSince(lastRefusal)
        // A refusal in the future means the clock moved backwards; don't wait for it to catch up.
        return elapsed >= retryInterval || elapsed < 0
    }

    /// Retired client identities receive a placeholder token made of one repeated character (all zeros).
    static func isUsableToken(_ token: String) -> Bool {
        guard let first = token.first else { return false }
        return token.contains { $0 != first }
    }

    // MARK: - Request with captcha/renew retry

    /// Sends the request with the current user token, rebuilding the URL on each attempt
    /// so a renewed token is actually used by the retry.
    private func requestWithRetry(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        for attempt in 0 ..< maxCaptchaRetries {
            let token = try await ensureToken()
            var components = URLComponents(string: "\(baseURL)/\(path)")!
            components.queryItems = queryItems + [URLQueryItem(name: "usertoken", value: token)]
            guard let url = components.url else { throw MusixmatchError.invalidResponse }

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
                            discardToken()
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
                discardToken()
                continue
            }

            throw MusixmatchError.httpError(httpResponse.statusCode)
        }

        throw MusixmatchError.captcha
    }

    // MARK: - Response Parsing

    /// Parse the macro.subtitles.get response, scored against the track Musixmatch actually matched.
    /// Musixmatch can answer every query with the same decoy track (e.g. "NOKIA — Drake" with
    /// gibberish lyrics), so the query metadata must never be trusted as the match.
    /// Fallback order: richsync (word-level) → subtitle (LRC) → plain lyrics (unsynced — skipped).
    func parseMacroResponse(_ data: Data, for track: TrackInfo) throws -> LyricsSearchResult? {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let macroCalls = body["macro_calls"] as? [String: Any],
              let matcher = macroCalls["matcher.track.get"] as? [String: Any],
              let matcherMessage = matcher["message"] as? [String: Any],
              let matcherBody = matcherMessage["body"] as? [String: Any],
              let matched = matcherBody["track"] as? [String: Any],
              let title = matched["track_name"] as? String,
              let artist = matched["artist_name"] as? String
        else {
            return nil
        }

        // The matcher can report track_length as 0; fall back to the returned subtitle's length
        // so the duration term still counts, instead of scoring a 0 s track or dropping the term.
        let trackLength = matched["track_length"] as? Int ?? 0
        let lengthSeconds = trackLength > 0 ? trackLength : subtitleLength(from: macroCalls)
        let candidate = TrackMatcher.Candidate(
            title: title,
            artist: artist,
            album: matched["album_name"] as? String,
            durationMs: lengthSeconds.map { $0 * 1000 }
        )
        let (score, confidence) = TrackMatcher.score(target: track, candidate: candidate)
        guard confidence >= .low else {
            logDebug("[musixmatch] Rejected mismatched track: \(title) — \(artist)")
            return nil
        }

        guard let lyrics = extractRichSync(from: macroCalls) ?? extractSubtitle(from: macroCalls) else {
            return nil
        }
        return LyricsSearchResult(
            provider: name,
            lyrics: lyrics,
            matchInfo: "\(title) \u{2014} \(artist)",
            score: score,
            confidence: confidence
        )
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

    /// Length in seconds of the first returned subtitle, if positive.
    private func subtitleLength(from macroCalls: [String: Any]) -> Int? {
        guard let subtitlesGet = macroCalls["track.subtitles.get"] as? [String: Any],
              let message = subtitlesGet["message"] as? [String: Any],
              let body = message["body"] as? [String: Any],
              let subtitleList = body["subtitle_list"] as? [[String: Any]],
              let subtitle = subtitleList.first?["subtitle"] as? [String: Any],
              let length = subtitle["subtitle_length"] as? Int,
              length > 0
        else {
            return nil
        }
        return length
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
