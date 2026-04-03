import SwiftUI

/// Full expanded state: scrollable lyrics list.
struct FullIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Album artwork on the left
            if appState.showArtwork {
                VStack {
                    ArtworkView(syncEngine: syncEngine, size: 200)
                        .padding(.top, 8)

                    // Source badge below artwork
                    if let source = lyricsManager.currentLyrics?.source {
                        Text(source)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.08)))
                            .padding(.top, 4)
                    }

                    Spacer()
                }
                .padding(.leading, 10)
            }

            // Lyrics on the right
            VStack(spacing: 0) {
                if let lyrics = lyricsManager.currentLyrics {
                    LyricsScrollView(lyrics: lyrics, syncEngine: syncEngine)
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
}
