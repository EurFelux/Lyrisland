import SwiftUI

/// Full expanded state: scrollable lyrics list.
struct FullIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    var body: some View {
        // Lyrics — artwork is handled by parent IslandContentView
        VStack(spacing: 0) {
            if let lyrics = lyricsManager.currentLyrics {
                LyricsScrollView(
                    lyrics: lyrics,
                    currentLineIndex: syncEngine.currentLineIndex ?? 0,
                    alignment: appState.resolvedLyricsAlignment
                )
            } else if lyricsManager.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white.opacity(0.5))
                Spacer()
            } else {
                Spacer()
                Text("lyrics.no_synced")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
            }
        }
    }
}
