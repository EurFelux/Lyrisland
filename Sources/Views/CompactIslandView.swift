import SwiftUI

/// Compact state: single-line song title + playing indicator.
/// When dual-line mode is on, also shows the upcoming next line below.
struct CompactIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

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

            // Lyrics display
            if appState.dualLineMode, let lyrics = lyricsManager.currentLyrics, let idx = currentLineIndex {
                // Dual-line mode: ForEach keyed by line index so SwiftUI tracks
                // the next line sliding up to become the current line
                let indices = idx + 1 < lyrics.lines.count ? [idx, idx + 1] : [idx]
                VStack(alignment: appState.resolvedHorizontalAlignment, spacing: 2) {
                    ForEach(indices, id: \.self) { lineIdx in
                        DualLineRow(text: lyrics.lines[lineIdx].text, isCurrent: lineIdx == idx)
                            .transition(.push(from: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.35), value: idx)
                .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
            } else {
                // Single-line mode: original MarqueeText behavior
                MarqueeText(
                    text: displayText,
                    font: .system(size: 13, weight: .medium),
                    color: displayTextOpacity,
                    loops: false
                )
                .transition(.push(from: .bottom).combined(with: .opacity))
                .id(currentLineIndex ?? -1)
                .animation(.smooth(duration: 0.35), value: currentLineIndex)
                .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
            }
        }
        // padding handled by parent IslandContentView
    }

    private var statusIcon: String {
        if !syncEngine.isPlaying, syncEngine.currentTrackId == nil {
            return "antenna.radiowaves.left.and.right.slash" // Not connected
        }
        return "pause.fill"
    }

    private var currentLineIndex: Int? {
        syncEngine.currentLineIndex
    }

    private var displayText: String {
        // Has lyrics loaded
        if let lyrics = lyricsManager.currentLyrics {
            if let idx = currentLineIndex {
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
        if lyricsManager.currentLyrics != nil, currentLineIndex != nil {
            return .white
        }
        return .white.opacity(0.5)
    }
}

/// Lightweight equatable row with marquee support for long text.
private struct DualLineRow: View, Equatable {
    let text: String
    let isCurrent: Bool

    var body: some View {
        MarqueeText(
            text: text,
            font: isCurrent ? .system(size: 13, weight: .medium) : .system(size: 11),
            color: isCurrent ? .white : .white.opacity(0.4),
            scrollEnabled: isCurrent,
            loops: false
        )
    }
}
