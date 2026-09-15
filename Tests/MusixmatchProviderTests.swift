import Foundation
@testable import Lyrisland
import Testing

struct MusixmatchProviderTests {
    /// Trimmed copy of the decoy response Musixmatch returned for every query (2026-09-15).
    private let decoyResponse = Data(#"""
    {"message":{"body":{"macro_calls":{
      "matcher.track.get":{"message":{"body":{"track":{
        "track_name":"NOKIA","artist_name":"Drake","album_name":"$ome $exy $ongs 4 U","track_length":null}}}},
      "track.subtitles.get":{"message":{"body":{"subtitle_list":[{"subtitle":{
        "subtitle_body":"[00:12.00]Wob gopini den\n[00:16.00]Tefe woxica fero"}}]}}}
    }}}}
    """#.utf8)

    private func track(_ title: String, _ artist: String, album: String, durationMs: Int = 180_000) -> TrackInfo {
        TrackInfo(id: "spotify:track:test", title: title, artist: artist, album: album, durationMs: durationMs)
    }

    /// A macro.subtitles.get response whose matcher returned the given track metadata.
    private func response(
        _ title: String,
        _ artist: String,
        album: String,
        lengthSeconds: Int,
        subtitleLengthSeconds: Int = 0
    ) throws -> Data {
        let body: [String: Any] = ["macro_calls": [
            "matcher.track.get": ["message": ["body": ["track": [
                "track_name": title, "artist_name": artist, "album_name": album, "track_length": lengthSeconds,
            ]]]],
            "track.subtitles.get": ["message": ["body": ["subtitle_list": [
                ["subtitle": [
                    "subtitle_body": "[00:12.00]First line\n[00:16.00]Second line",
                    "subtitle_length": subtitleLengthSeconds,
                ]],
            ]]]],
        ]]
        return try JSONSerialization.data(withJSONObject: ["message": ["body": body]])
    }

    @Test("rejects lyrics when Musixmatch matched a different track")
    func rejectsMismatchedTrack() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            decoyResponse,
            for: track("404 (New Era)", "KiiiKiii", album: "Delulu Pack")
        )
        #expect(result == nil)
    }

    @Test("accepts lyrics when the matched track is the playing track")
    func acceptsMatchingTrack() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            decoyResponse,
            for: track("NOKIA", "Drake", album: "$ome $exy $ongs 4 U")
        )
        #expect(result?.lyrics.lines.count == 2)
        #expect(result?.matchInfo == "NOKIA \u{2014} Drake")
        #expect(result?.score == 30)
    }

    @Test("accepts a localized title when artist, album and duration match")
    func acceptsLocalizedTitle() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            response("Racing Into The Night", "YOASOBI", album: "THE BOOK", lengthSeconds: 261),
            for: track("夜に駆ける", "YOASOBI", album: "THE BOOK", durationMs: 261_000)
        )
        // Title scores 0; artist 7 + album 7 × 0.4 + duration 7, out of 23.8, normalized to 30.
        let expected = (7 + 2.8 + 7) / 23.8 * 30
        let score = try #require(result?.score)
        #expect(abs(score - expected) < 0.001)
        #expect(result?.matchInfo == "Racing Into The Night \u{2014} YOASOBI")
    }

    @Test("scores the matched metadata instead of reporting a perfect match")
    func scoresMatchedMetadata() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            response("Drama", "aespa", album: "Drama", lengthSeconds: 213),
            for: track("Drama", "aespa", album: "Drama", durationMs: 214_000)
        )
        // Title 7 + artist 7 + album 7 × 0.4 + duration 4 (1 s off), out of 23.8, normalized to 30.
        let expected = (7 + 7 + 2.8 + 4) / 23.8 * 30
        let score = try #require(result?.score)
        #expect(abs(score - expected) < 0.001)
        #expect(score < 30)
    }

    @Test("falls back to subtitle_length when track_length is 0")
    func fallsBackToSubtitleLength() throws {
        let playing = track("夜に駆ける", "YOASOBI", album: "THE BOOK", durationMs: 261_000)
        let matching = try MusixmatchProvider().parseMacroResponse(
            response("夜に駆ける", "YOASOBI", album: "THE BOOK", lengthSeconds: 0, subtitleLengthSeconds: 261),
            for: playing
        )
        #expect(matching?.score == 30)

        // An 11 s longer subtitle scores duration 0, so the fallback visibly lowers the score.
        let wrongLength = try MusixmatchProvider().parseMacroResponse(
            response("夜に駆ける", "YOASOBI", album: "THE BOOK", lengthSeconds: 0, subtitleLengthSeconds: 272),
            for: playing
        )
        let score = try #require(wrongLength?.score)
        #expect(abs(score - (7 + 7 + 2.8) / 23.8 * 30) < 0.001)
    }

    @Test("rejects the placeholder token issued to retired client identities")
    func rejectsPlaceholderToken() {
        #expect(!MusixmatchProvider.isUsableToken(String(repeating: "0", count: 56)))
        #expect(!MusixmatchProvider.isUsableToken(""))
        #expect(MusixmatchProvider.isUsableToken("0001"))
        #expect(MusixmatchProvider.isUsableToken("abc123def456"))
    }
}
