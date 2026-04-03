import SwiftUI

/// Compact state: single-line song title + playing indicator.
struct CompactIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager

    var body: some View {
        HStack(spacing: 10) {
            // Playing indicator bars
            if syncEngine.isPlaying {
                PlayingIndicator()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Status-aware text
            Text(displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(displayTextOpacity)
                .lineLimit(1)
                .transition(.push(from: .bottom))
                .id(currentLineId)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var statusIcon: String {
        if !syncEngine.isPlaying, syncEngine.position == 0 {
            return "antenna.radiowaves.left.and.right.slash" // Not connected
        }
        return "pause.fill"
    }

    private var currentLineId: Int? {
        guard let lyrics = lyricsManager.currentLyrics else { return nil }
        return lyrics.lineIndex(at: syncEngine.position)
    }

    private var displayText: String {
        // Has lyrics loaded
        if let lyrics = lyricsManager.currentLyrics {
            if let idx = lyrics.lineIndex(at: syncEngine.position) {
                return lyrics.lines[idx].text
            }
            // Before first line — lyrics are loaded but haven't started yet
            return "♪"
        }

        // Loading lyrics
        if lyricsManager.isLoading {
            return String(localized: "lyrics.loading")
        }

        // Playing but no lyrics found
        if syncEngine.isPlaying {
            return String(localized: "lyrics.not_available")
        }

        // Paused with a known position (Spotify running but paused)
        if syncEngine.position > 0 {
            return String(localized: "lyrics.paused")
        }

        // Spotify not running or no track
        return String(localized: "lyrics.play_to_start")
    }

    private var displayTextOpacity: Color {
        if let lyrics = lyricsManager.currentLyrics,
           lyrics.lineIndex(at: syncEngine.position) != nil {
            return .white
        }
        return .white.opacity(0.5)
    }
}
