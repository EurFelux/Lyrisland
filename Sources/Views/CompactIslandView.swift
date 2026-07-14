import SwiftUI

/// Compact state: playing indicator + single-line lyrics (current song title
/// / lyric line). When dual-line mode is on, ``CompactLyricsView`` also shows
/// the upcoming next line below.
struct CompactIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            PlayingStatusIndicator(syncEngine: syncEngine)
            CompactLyricsView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
        }
        // padding handled by parent IslandContentView
    }
}
