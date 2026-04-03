import SwiftUI

/// Expanded state: shows the current lyric line with surrounding context.
/// When dual-line mode is on, the next line is styled distinctly from context lines.
struct ExpandedIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    private let visibleLineCount = 5

    var body: some View {
        // Lyrics — artwork is handled by parent IslandContentView
        VStack(spacing: 4) {
            // Track info header
            if let title = syncEngine.trackTitle {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    if let artist = syncEngine.trackArtist {
                        Text("—")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let lyrics = lyricsManager.currentLyrics {
                let currentIdx = syncEngine.currentLineIndex ?? 0
                let range = contextRange(around: currentIdx, total: lyrics.lines.count)

                ForEach(lyrics.lines[range]) { line in
                    let isCurrent = line.id == lyrics.lines[currentIdx].id
                    let isNext = appState.dualLineMode && line.id == currentIdx + 1
                    if isCurrent {
                        MarqueeText(
                            text: line.text,
                            font: .system(size: 15, weight: .bold),
                            color: .white,
                            loops: false
                        )
                        .frame(height: 20)
                        .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else if isNext {
                        Text(line.text)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Text(line.text)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
                            .blur(radius: 0.5)
                            .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    }
                }
            } else {
                Text("lyrics.no_lyrics")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        // padding handled by parent IslandContentView
        .animation(.smooth(duration: 0.35), value: syncEngine.currentLineIndex)
    }

    private func contextRange(around index: Int, total: Int) -> ClosedRange<Int> {
        let half = visibleLineCount / 2
        let start = max(0, index - half)
        let end = min(total - 1, start + visibleLineCount - 1)
        let adjustedStart = max(0, end - visibleLineCount + 1)
        return adjustedStart ... end
    }
}
