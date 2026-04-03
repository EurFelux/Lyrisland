import SwiftUI

/// The root view hosted inside the DynamicIslandPanel.
struct IslandContentView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState
    @State private var islandState: IslandState = .compact
    @State private var isAttached: Bool = UserDefaults.standard.islandPositionMode == .attached

    private var cornerRadius: CGFloat {
        islandState == .compact ? 20 : 24
    }

    var body: some View {
        ZStack(alignment: isAttached ? .bottom : .topLeading) {
            // Background: attached mode has inverse top corners, detached has full rounded corners
            if isAttached {
                IslandBackgroundView(
                    style: appState.backgroundStyle,
                    shape: AnyShape(AttachedIslandShape(bottomRadius: cornerRadius, inverseRadius: Self.earRadius)),
                    trackId: syncEngine.currentTrackId,
                    artworkURL: syncEngine.artworkURL,
                    isPlaying: syncEngine.isPlaying,
                    solidColor: appState.solidColor
                )
                .overlay(
                    AttachedIslandShape(
                        bottomRadius: cornerRadius,
                        inverseRadius: Self.earRadius
                    )
                    .stroke(.white.opacity(0.15), lineWidth: 0.5)
                )
            } else {
                IslandBackgroundView(
                    style: appState.backgroundStyle,
                    shape: AnyShape(RoundedRectangle(cornerRadius: cornerRadius)),
                    trackId: syncEngine.currentTrackId,
                    artworkURL: syncEngine.artworkURL,
                    isPlaying: syncEngine.isPlaying
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )
            }

            // In attached mode, content is aligned to the bottom so it appears below the menu bar
            HStack(spacing: 10) {
                if appState.showArtwork {
                    artworkColumn
                }

                switch islandState {
                case .compact:
                    CompactIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                case .expanded:
                    ExpandedIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                case .full:
                    FullIslandView(syncEngine: syncEngine, lyricsManager: lyricsManager, appState: appState)
                }
            }
            .frame(
                maxHeight: isAttached
                    ? Self.contentHeight(for: islandState, dualLine: appState.dualLineMode, artwork: appState.showArtwork)
                    : .infinity
            )
            .padding(.horizontal, isAttached ? Self.earRadius : 0)
            .padding(contentPadding)
        }
        // No explicit size — fill the panel, let NSPanel drive sizing
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isAttached ? .bottom : .topLeading)
        .clipShape(
            isAttached
                ? AnyShape(AttachedIslandShape(bottomRadius: cornerRadius, inverseRadius: Self.earRadius))
                : AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
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

    // MARK: - Artwork (single persistent instance)

    private var artworkColumn: some View {
        VStack(spacing: 0) {
            ArtworkView(trackId: syncEngine.currentTrackId, artworkURL: syncEngine.artworkURL, size: artworkSize)
                .padding(.top, islandState == .full ? 8 : 0)

            if islandState == .full {
                if let source = lyricsManager.currentLyrics?.source {
                    Text(source)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.08)))
                        .padding(.top, 4)
                }

                // Track info
                VStack(spacing: 2) {
                    if let title = syncEngine.trackTitle {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    if let artist = syncEngine.trackArtist {
                        Text(artist)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

                // Remaining space: controls centered within it
                PlaybackControlsView(syncEngine: syncEngine)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var artworkSize: CGFloat {
        switch islandState {
        case .compact: 36
        case .expanded: 110
        case .full: 200
        }
    }

    private var contentPadding: EdgeInsets {
        switch islandState {
        case .compact:
            EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        case .expanded:
            // In attached mode, move bottom padding to top so the content clears the notch.
            // The bottom padding otherwise pushes the bottom-aligned content up into the menu bar area.
            if isAttached {
                EdgeInsets(top: 24, leading: 10, bottom: 0, trailing: 10)
            } else {
                EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
            }
        case .full:
            EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
        }
    }

    // MARK: - Sizing

    /// Extra height to extend behind the notch/menu bar in attached mode.
    /// Only needed on notched displays where the island emerges from the notch.
    /// Non-notch screens get no extension — the island sits flush at the screen top.
    static func menuBarHeight(for screen: NSScreen? = nil) -> CGFloat {
        guard let screen = screen ?? NSScreen.main else { return 0 }
        guard screen.hasNotch else { return 0 }
        return screen.frame.maxY - screen.visibleFrame.maxY
    }

    /// The content-only height (without menu bar extension).
    static func contentHeight(for state: IslandState, dualLine: Bool = false, artwork: Bool = true) -> CGFloat {
        switch state {
        case .compact: dualLine ? 62 : artwork ? 48 : 38
        case .expanded: artwork ? 140 : 120
        case .full: artwork ? 340 : 340
        }
    }

    /// Radius of the inverse corner "ears" in attached mode.
    static let earRadius: CGFloat = 10

    static func size(
        for state: IslandState,
        attached: Bool = false,
        dualLine: Bool = false,
        artwork: Bool = true,
        screen: NSScreen? = nil
    ) -> NSSize {
        let h = contentHeight(for: state, dualLine: dualLine, artwork: artwork)
        let w: CGFloat = switch state {
        case .compact: 350
        case .expanded: artwork ? 450 : 380
        case .full: artwork ? 540 : 400
        }
        if attached {
            return NSSize(width: w, height: h + menuBarHeight(for: screen))
        }
        return NSSize(width: w, height: h)
    }

    private func cycleState() {
        withAnimation(.easeOut(duration: 0.35)) {
            switch islandState {
            case .compact: islandState = .expanded
            case .expanded: islandState = .full
            case .full: islandState = .compact
            }
        }
    }

    private func resizePanel(for state: IslandState) {
        guard let window = NSApp.windows.first(where: { $0 is DynamicIslandPanel }) as? DynamicIslandPanel else { return }
        window.animateResize(to: Self.size(
            for: state,
            attached: isAttached,
            dualLine: appState.dualLineMode,
            artwork: appState.showArtwork,
            screen: window.screen
        ))
    }
}
