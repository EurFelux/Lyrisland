import SwiftUI

/// The root view hosted inside the DynamicIslandPanel.
struct IslandContentView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState
    @State private var islandState: IslandState = .compact

    var body: some View {
        ZStack {
            // Background capsule
            RoundedRectangle(cornerRadius: islandState == .compact ? 20 : 24)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: islandState == .compact ? 20 : 24)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )

            // Content based on state — `tick` dependency ensures periodic redraws
            let _ = syncEngine.tick // swiftlint:disable:this redundant_discardable_let
            switch islandState {
            case .compact:
                CompactIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
            case .expanded:
                ExpandedIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
            case .full:
                FullIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
            }
        }
        .frame(width: widthForState, height: heightForState)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: islandState)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.dualLineMode)
        .onReceive(NotificationCenter.default.publisher(for: .islandTapped)) { _ in
            cycleState()
        }
        .onChange(of: islandState) { _, newState in
            resizePanel(for: newState)
        }
        .onChange(of: appState.dualLineMode) { _, _ in
            resizePanel(for: islandState)
        }
        .onChange(of: appState.showArtwork) { _, _ in
            resizePanel(for: islandState)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showArtwork)
    }

    private var widthForState: CGFloat {
        Self.size(for: islandState, dualLine: appState.dualLineMode, artwork: appState.showArtwork).width
    }

    private var heightForState: CGFloat {
        Self.size(for: islandState, dualLine: appState.dualLineMode, artwork: appState.showArtwork).height
    }

    static func size(for state: IslandState, dualLine: Bool = false, artwork: Bool = true) -> NSSize {
        switch state {
        case .compact: NSSize(width: 350, height: dualLine ? 62 : artwork ? 48 : 38)
        case .expanded: NSSize(width: artwork ? 450 : 380, height: artwork ? 160 : 120)
        case .full: NSSize(width: artwork ? 540 : 400, height: artwork ? 340 : 300)
        }
    }

    private func cycleState() {
        switch islandState {
        case .compact: islandState = .expanded
        case .expanded: islandState = .full
        case .full: islandState = .compact
        }
    }

    private func resizePanel(for state: IslandState) {
        guard let window = NSApp.windows.first(where: { $0 is DynamicIslandPanel }) as? DynamicIslandPanel else { return }
        window.animateResize(to: Self.size(for: state, dualLine: appState.dualLineMode, artwork: appState.showArtwork))
    }
}
