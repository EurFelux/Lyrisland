import SwiftUI

/// Expanded state: shows the current lyric line with surrounding context.
/// Uses push transitions (like Compact mode) for smooth line-by-line scrolling.
struct ExpandedIslandView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    private let visibleLineCount = 5

    var body: some View {
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
                    let isCurrent = line.id == currentIdx
                    let distance = abs(line.id - currentIdx)
                    let lineDirection: LayoutDirection = line.text.isRTL ? .rightToLeft : .leftToRight

                    if isCurrent {
                        MarqueeText(
                            text: line.text,
                            font: .system(size: 15, weight: .bold),
                            color: .white,
                            loops: false,
                            lineDuration: lineDuration(for: currentIdx, in: lyrics)
                        )
                        .frame(height: 20)
                        .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
                        .environment(\.layoutDirection, lineDirection)
                        .transition(.push(from: .bottom))
                    } else {
                        Text(line.text)
                            .font(.system(
                                size: distance == 1 ? 13 : 12,
                                weight: distance == 1 ? .medium : .regular
                            ))
                            .foregroundStyle(.white.opacity(opacityFor(distance: distance)))
                            .lineLimit(1)
                            .blur(radius: blurFor(distance: distance))
                            .frame(height: 20)
                            .frame(maxWidth: .infinity, alignment: appState.resolvedLyricsAlignment)
                            .environment(\.layoutDirection, lineDirection)
                            .transition(.push(from: .bottom))
                    }
                }
                .id(currentIdx)
            } else {
                Text("lyrics.no_lyrics")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.smooth(duration: 0.35), value: syncEngine.currentLineIndex)
    }

    private func contextRange(around index: Int, total: Int) -> ClosedRange<Int> {
        let half = visibleLineCount / 2
        let start = max(0, index - half)
        let end = min(total - 1, start + visibleLineCount - 1)
        let adjustedStart = max(0, end - visibleLineCount + 1)
        return adjustedStart ... end
    }

    private func opacityFor(distance: Int) -> Double {
        switch distance {
        case 1: 0.55
        case 2: 0.3
        default: 0.15
        }
    }

    private func blurFor(distance: Int) -> CGFloat {
        switch distance {
        case 1: 0
        case 2: 0.3
        default: 0.8
        }
    }

    private func lineDuration(for index: Int, in lyrics: SyncedLyrics) -> Double? {
        guard index + 1 < lyrics.lines.count else { return nil }
        return lyrics.lines[index + 1].time - lyrics.lines[index].time
    }
}
