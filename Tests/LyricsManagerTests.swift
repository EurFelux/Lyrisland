import Foundation
@testable import Lyrisland
import Testing

struct LyricsManagerTests {
    private let registryOrder = ["lrclib": 0, "qqmusic": 4]

    private func result(provider: String, score: Double) -> LyricsSearchResult {
        LyricsSearchResult(
            provider: provider,
            lyrics: SyncedLyrics(lines: [], source: provider, globalOffset: 0),
            matchInfo: "track",
            score: score,
            confidence: .perfect
        )
    }

    @Test("equal scores follow registry order regardless of arrival order")
    func equalScoresFollowRegistryOrder() {
        let lrclib = result(provider: "lrclib", score: 30)
        let qqmusic = result(provider: "qqmusic", score: 30)

        #expect(LyricsManager.shouldReplaceBest(lrclib, current: qqmusic, providerOrder: registryOrder))
        #expect(!LyricsManager.shouldReplaceBest(qqmusic, current: lrclib, providerOrder: registryOrder))
    }

    @Test("a higher score wins over registry order")
    func higherScoreWins() {
        let lrclib = result(provider: "lrclib", score: 25)
        let qqmusic = result(provider: "qqmusic", score: 30)

        #expect(LyricsManager.shouldReplaceBest(qqmusic, current: lrclib, providerOrder: registryOrder))
        #expect(!LyricsManager.shouldReplaceBest(lrclib, current: qqmusic, providerOrder: registryOrder))
    }
}
