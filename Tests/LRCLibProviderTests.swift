import Foundation
@testable import Lyrisland
import Testing

struct LRCLibProviderTests {
    private let track = TrackInfo(
        id: "spotify:track:test",
        title: "Drama",
        artist: "aespa",
        album: "Drama - The 4th Mini Album",
        durationMs: 214_973
    )

    /// Build search hits through JSONSerialization so numbers are NSNumber, as in real responses.
    private func hits(_ json: String) throws -> [[String: Any]] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
    }

    private func hit(album: String, duration: String) -> String {
        #"{"trackName":"Drama","artistName":"aespa","albumName":"\#(album)","duration":\#(duration),"syncedLyrics":"[00:02.93]I'm the drama"}"#
    }

    @Test("ranks every hit before applying the limit")
    func ranksBeforeLimit() throws {
        let provider = LRCLibProvider()
        let wrongAlbumFirst = try hits("[\(hit(album: "aespa", duration: "215")),\(hit(album: "Drama", duration: "215"))]")
        let rightAlbumOnly = try hits("[\(hit(album: "Drama", duration: "215"))]")

        let best = provider.rankedResults(wrongAlbumFirst, for: track, limit: 1)
        #expect(best.count == 1)
        #expect(best.first?.score == provider.rankedResults(rightAlbumOnly, for: track, limit: 1).first?.score)
    }

    @Test("fractional durations still count toward the score")
    func fractionalDurationIsScored() throws {
        let provider = LRCLibProvider()
        let wrongLength = try provider.rankedResults(hits("[\(hit(album: "Drama", duration: "141.84"))]"), for: track, limit: 1)
        let rightLength = try provider.rankedResults(hits("[\(hit(album: "Drama", duration: "214.97"))]"), for: track, limit: 1)

        #expect(try #require(wrongLength.first?.score) < #require(rightLength.first?.score))
    }
}
