import Foundation
@testable import Lyrisland
import Testing

@MainActor
struct PlaybackSyncEngineTests {
    private func lyrics(lineCount: Int) -> SyncedLyrics {
        SyncedLyrics(
            lines: (0 ..< lineCount).map { LyricLine(id: $0, time: TimeInterval($0), text: "line \($0)", translation: nil) },
            source: "test",
            globalOffset: 0
        )
    }

    @Test("lyrics loaded while paused never keep the previous track's out-of-range line index")
    func lyricsChangeWhilePausedRecomputesIndex() {
        let engine = PlaybackSyncEngine()
        engine.calibrate(position: 100, isPlaying: false)

        engine.lyricsDidChange(lyrics(lineCount: 200))
        #expect(engine.currentLineIndex == 100)

        engine.lyricsDidChange(lyrics(lineCount: 3))
        #expect(engine.currentLineIndex == 2)

        engine.lyricsDidChange(nil)
        #expect(engine.currentLineIndex == nil)
    }
}
