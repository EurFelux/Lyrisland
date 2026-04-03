import SwiftUI

/// The root view hosted inside the DynamicIslandPanel.
struct IslandContentView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState
    @State private var islandState: IslandState = .compact
    @State private var isAttached: Bool = UserDefaults.standard.islandPositionMode == .attached

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background: attached mode has inverse top corners, detached has full rounded corners
            if isAttached {
                AttachedIslandShape(
                    bottomRadius: islandState == .compact ? 20 : 24,
                    inverseRadius: Self.earRadius
                )
                .fill(Color(white: 0.08))
                .overlay(
                    AttachedIslandShape(
                        bottomRadius: islandState == .compact ? 20 : 24,
                        inverseRadius: Self.earRadius
                    )
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
            } else {
                RoundedRectangle(cornerRadius: islandState == .compact ? 20 : 24)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: islandState == .compact ? 20 : 24)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                    )
            }

            // Content based on state — `tick` dependency ensures periodic redraws
            // In attached mode, content is aligned to the bottom so it appears below the menu bar
            let _ = syncEngine.tick // swiftlint:disable:this redundant_discardable_let
            Group {
                switch islandState {
                case .compact:
                    CompactIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                case .expanded:
                    ExpandedIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                case .full:
                    FullIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                }
            }
            .frame(height: Self.contentHeight(for: islandState, dualLine: appState.dualLineMode, artwork: appState.showArtwork))
            .padding(.horizontal, isAttached ? Self.earRadius : 0)
        }
        .frame(width: widthForState, height: heightForState)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: islandState)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.dualLineMode)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appState.showArtwork)
        .onReceive(NotificationCenter.default.publisher(for: .islandTapped)) { _ in
            cycleState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .islandPositionModeChanged)) { notification in
            if let mode = notification.object as? IslandPositionMode {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAttached = mode == .attached
                }
                resizePanel(for: islandState)
            }
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
    }

    /// Height of the menu bar area (the part hidden behind the notch/menu bar).
    static var menuBarHeight: CGFloat {
        guard let screen = NSScreen.main else { return 25 }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    private var widthForState: CGFloat {
        size(for: islandState).width
    }

    private var heightForState: CGFloat {
        size(for: islandState).height
    }

    func size(for state: IslandState) -> NSSize {
        Self.size(for: state, attached: isAttached, dualLine: appState.dualLineMode, artwork: appState.showArtwork)
    }

    /// The content-only height (without menu bar extension).
    static func contentHeight(for state: IslandState, dualLine: Bool = false, artwork: Bool = true) -> CGFloat {
        switch state {
        case .compact: dualLine ? 62 : artwork ? 48 : 38
        case .expanded: artwork ? 160 : 120
        case .full: artwork ? 340 : 300
        }
    }

    /// Radius of the inverse corner "ears" in attached mode.
    static let earRadius: CGFloat = 10

    static func size(for state: IslandState, attached: Bool = false, dualLine: Bool = false, artwork: Bool = true) -> NSSize {
        let h = contentHeight(for: state, dualLine: dualLine, artwork: artwork)
        let w: CGFloat = switch state {
        case .compact: 350
        case .expanded: artwork ? 450 : 380
        case .full: artwork ? 540 : 400
        }
        if attached {
            return NSSize(width: w, height: h + menuBarHeight)
        }
        return NSSize(width: w, height: h)
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
        window.animateResize(to: Self.size(
            for: state,
            attached: isAttached,
            dualLine: appState.dualLineMode,
            artwork: appState.showArtwork
        ))
    }
}
