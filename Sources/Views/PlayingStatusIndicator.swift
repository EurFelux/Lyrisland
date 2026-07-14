import SwiftUI

/// Playing/paused indicator shared by the compact layouts: animated sound
/// bars while playing, or a status icon (paused / not connected) otherwise.
struct PlayingStatusIndicator: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @Environment(\.rootFontSize) private var rootFontSize
    @Environment(\.contentColor) private var contentColor

    var body: some View {
        if syncEngine.isPlaying {
            PlayingIndicator()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: statusIcon)
                .font(.system(size: .rem(0.625, root: rootFontSize)))
                .foregroundStyle(contentColor.opacity(0.6))
        }
    }

    private var statusIcon: String {
        if !syncEngine.isPlaying, syncEngine.currentTrackId == nil {
            return "antenna.radiowaves.left.and.right.slash" // Not connected
        }
        return "pause.fill"
    }
}
