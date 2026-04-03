import SwiftUI

/// Auto-scrolling lyrics list that tracks the current playback position.
/// Only re-renders when the current line index changes, not on every tick.
struct LyricsScrollView: View {
    let lyrics: SyncedLyrics
    let currentLineIndex: Int
    var alignment: Alignment = .leading

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    Spacer(minLength: 40)

                    ForEach(lyrics.lines) { line in
                        LyricLineRow(
                            text: line.text,
                            translation: line.translation,
                            isCurrent: line.id == currentLineIndex,
                            distance: abs(line.id - currentLineIndex)
                        )
                        .frame(maxWidth: .infinity, alignment: alignment)
                        .id(line.id)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: currentLineIndex) { _, newIdx in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIdx, anchor: .center)
                }
            }
        }
    }
}

/// Individual lyric line — Equatable so SwiftUI skips body evaluation
/// when this line's state hasn't changed (only ~2 lines change per index shift).
private struct LyricLineRow: View, Equatable {
    let text: String
    let translation: String?
    let isCurrent: Bool
    let distance: Int

    var body: some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(size: isCurrent ? 15 : 12, weight: isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                .blur(radius: blurAmount)
                .scaleEffect(isCurrent ? 1.0 : 0.95)

            if let translation {
                Text(translation)
                    .font(.system(size: 11))
                    .foregroundStyle(isCurrent ? .white.opacity(0.7) : .white.opacity(0.2))
            }
        }
        .animation(.smooth(duration: 0.35), value: isCurrent)
    }

    private var blurAmount: CGFloat {
        if distance == 0 { return 0 }
        if distance <= 2 { return 0.3 }
        return 0.8
    }
}
