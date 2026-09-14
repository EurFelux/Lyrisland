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

    private func track(_ title: String, _ artist: String, album: String) -> TrackInfo {
        TrackInfo(id: "spotify:track:test", title: title, artist: artist, album: album, durationMs: 180_000)
    }

    @Test("rejects lyrics when Musixmatch matched a different track")
    func rejectsMismatchedTrack() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            decoyResponse,
            for: track("404 (New Era)", "KiiiKiii", album: "Delulu Pack")
        )
        #expect(result == nil)
    }

    @Test("rejects the decoy for other songs by the decoy's artist")
    func rejectsArtistOnlyMatch() throws {
        let result = try MusixmatchProvider().parseMacroResponse(
            decoyResponse,
            for: track("God's Plan", "Drake", album: "Scorpion")
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
    }
}
