import SwiftUI

/// Playback controls with previous, play/pause, and next buttons.
struct PlaybackControlsView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine

    var body: some View {
        HStack(spacing: 20) {
            Button { syncEngine.previousTrack() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
            }
            Button { syncEngine.playPause() } label: {
                Image(systemName: syncEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
            }
            Button { syncEngine.nextTrack() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.7))
    }
}
