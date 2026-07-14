import SwiftUI

/// Compact layout for notched displays in attached mode: artwork and the
/// playing indicator sit in "ears" flanking the notch, with the lyrics on a
/// full-width row below. Only used when compact + attached + notch present;
/// all other cases use the horizontal ``CompactIslandView``.
struct NotchHuggingCompactView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState

    /// Width of the notch cut-out (the gap between the two ears).
    let notchWidth: CGFloat
    /// Height of the top ear row (≈ menu bar / notch height).
    let notchHeight: CGFloat
    /// Width of each ear.
    let earWidth: CGFloat
    /// Inset matching the shape's outer concave corner, so ear content stays
    /// balanced between the outer edge and the notch instead of hugging the
    /// outer concave corner.
    let earInset: CGFloat

    @Environment(\.rootFontSize) private var rootFontSize
    @Environment(\.contentColor) private var contentColor

    /// Horizontal inset for the lyrics row so long lines don't touch the
    /// rounded/concave edges.
    private static let lyricsHorizontalInset: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            // Top row: ears flanking the notch, level with the menu bar. The
            // outer earInset spacers keep artwork/indicator clear of the
            // concave corners so their inner/outer padding is symmetric.
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(width: earInset)
                leftEar
                    .frame(width: earWidth - earInset)
                Spacer(minLength: 0)
                    .frame(width: notchWidth)
                rightEar
                    .frame(width: earWidth - earInset)
                Spacer(minLength: 0)
                    .frame(width: earInset)
            }
            .frame(height: notchHeight)

            // Bottom row: lyrics, inset from the rounded edges so long lines
            // don't run into them.
            CompactLyricsView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Self.lyricsHorizontalInset)
        }
    }

    /// Left ear: album artwork, or a music-note placeholder when the user has
    /// turned artwork off (keeps the layout symmetric without loading the art).
    @ViewBuilder private var leftEar: some View {
        if appState.showArtwork {
            ArtworkView(
                trackId: syncEngine.currentTrackId,
                artworkURL: syncEngine.artworkURL,
                size: earArtworkSize
            )
        } else {
            Image(systemName: "music.note")
                .font(.system(size: .rem(0.75, root: rootFontSize)))
                .foregroundStyle(contentColor.opacity(0.5))
                .frame(width: earArtworkSize, height: earArtworkSize)
        }
    }

    /// Right ear: playing indicator / status icon.
    private var rightEar: some View {
        PlayingStatusIndicator(syncEngine: syncEngine)
    }

    /// Artwork/placeholder side length, kept inside the ear with a little inset.
    private var earArtworkSize: CGFloat {
        max(0, min(earWidth - earInset, notchHeight) - 6)
    }
}
