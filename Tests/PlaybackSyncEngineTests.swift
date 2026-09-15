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

    @Test("paused lyrics changes update the index through the manager subscription")
    func lyricsChangeWhilePausedRecomputesIndex() async {
        let cache = Cache<String, SyncedLyrics>(memoryCountLimit: 10)
        let manager = LyricsManager(cache: cache)
        manager.updateProviderSettings(ProviderSettings(entries: []))
        let engine = PlaybackSyncEngine()
        engine.lyricsManager = manager
        engine.calibrate(position: 100, isPlaying: false)

        let track = TrackInfo(
            id: UUID().uuidString, title: "test", artist: "test", album: "test", durationMs: 200_000
        )
        await cache.set(lyrics(lineCount: 200), forKey: track.id)
        await manager.loadLyrics(for: track)
        #expect(engine.currentLineIndex == 100)

        await cache.set(lyrics(lineCount: 3), forKey: track.id)
        await manager.loadLyrics(for: track)
        #expect(engine.currentLineIndex == 2)

        // Offset changes publish without first clearing lyrics. Reading the old property
        // from the willSet notification would leave this at line 2 instead of line 0.
        manager.adjustOffset(by: -100)
        #expect(engine.currentLineIndex == 0)

        await cache.set(lyrics(lineCount: 0), forKey: track.id)
        await manager.loadLyrics(for: track)
        #expect(engine.currentLineIndex == nil)

        await cache.set(lyrics(lineCount: 200), forKey: track.id)
        await manager.loadLyrics(for: track)
        #expect(engine.currentLineIndex == 100)

        await cache.removeAll()
        await manager.loadLyrics(for: track)
        #expect(manager.currentLyrics?.lines == nil)
        #expect(engine.currentLineIndex == nil)
        #expect(!engine.isPlaying)
    }
}
