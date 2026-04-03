import SwiftUI

/// Playback controls with previous, play/pause, and next buttons.
struct PlaybackControlsView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @Environment(\.rootFontSize) private var rootFontSize

    var body: some View {
        HStack(spacing: 20) {
            Button { syncEngine.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: .rem(0.875, root: rootFontSize)))
            }
            Button { syncEngine.playPause() } label: {
                Image(systemName: syncEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: .rem(1.125, root: rootFontSize)))
            }
            Button { syncEngine.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: .rem(0.875, root: rootFontSize)))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.7))
    }
}
