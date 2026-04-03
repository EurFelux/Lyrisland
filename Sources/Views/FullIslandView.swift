import SwiftUI

/// Full expanded state: scrollable lyrics list.
struct FullIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState
    @Environment(\.rootFontSize) private var rootFontSize

    var body: some View {
        // Lyrics — artwork is handled by parent IslandContentView
        VStack(spacing: 0) {
            // Track info + controls header (only when artwork column is hidden)
            if !appState.showArtwork {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = syncEngine.trackTitle {
                            Text(title)
                                .font(.system(size: .rem(0.8125, root: rootFontSize), weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        if let artist = syncEngine.trackArtist {
                            Text(artist)
                                .font(.system(size: .rem(0.6875, root: rootFontSize)))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    PlaybackControlsView(syncEngine: syncEngine)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if let lyrics = lyricsManager.currentLyrics {
                LyricsScrollView(
                    lyrics: lyrics,
                    currentLineIndex: syncEngine.currentLineIndex ?? 0,
                    alignment: appState.resolvedLyricsAlignment
                )
            } else if lyricsManager.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white.opacity(0.5))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            } else {
                Text("lyrics.no_synced")
                    .font(.system(size: .rem(0.8125, root: rootFontSize)))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
            }
        }
    }
}
