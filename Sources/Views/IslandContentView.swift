import SwiftUI

/// The root view hosted inside the DynamicIslandPanel.
struct IslandContentView: View {
    @ObservedObject var syncEngine: PlaybackSyncEngine
    @ObservedObject var lyricsManager: LyricsManager
    @ObservedObject var appState: AppState
    @State private var islandState: IslandState = .compact
    @State private var isAttached: Bool = UserDefaults.standard.islandPositionMode == .attached
    @State private var isInSnapZone = false
    @State private var notchWidth: CGFloat? = NSScreen.main?.notchWidth
    @State private var notchHeight: CGFloat = IslandContentView.menuBarHeight(for: NSScreen.main)

    private var cornerRadius: CGFloat {
        islandState == .compact ? 20 : 24
    }

    /// Whether the island should use attached visual appearance (actual attached or snap zone preview).
    private var showAttachedAppearance: Bool {
        isAttached || isInSnapZone
    }

    /// Whether to use the notch-hugging compact layout: compact state, truly
    /// attached (not just a snap-zone preview), and a measurable notch on the
    /// current screen. Every other case uses the horizontal layout.
    private var isNotchHugging: Bool {
        Self.usesNotchHugging(state: islandState, attached: isAttached, notchWidth: notchWidth)
    }

    var body: some View {
        Group {
            if isNotchHugging {
                notchHuggingBody
            } else {
                standardBody
            }
        }
        .environment(\.rootFontSize, appState.rootFontSize)
        .environment(\.contentColor, appState.contentColor)
        .shadow(color: appState.contentColor.opacity(isInSnapZone ? 0.3 : 0), radius: 8)
        .onAppear {
            refreshNotchGeometry()
            // The panel was created before its screen (and the user's artwork /
            // dual-line settings) were known, so re-derive its frame now.
            resizePanel(for: islandState)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            // Resolution change / display hot-plug / main-display switch can
            // change the notch geometry while attached — refresh and resize.
            refreshNotchGeometry()
            resizePanel(for: islandState)
        }
        .onReceive(NotificationCenter.default.publisher(for: .islandTapped)) { _ in
            cycleState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .islandPositionModeChanged)) { notification in
            if let mode = notification.object as? IslandPositionMode {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isAttached = mode == .attached
                }
                refreshNotchGeometry()
                resizePanel(for: islandState)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .islandSnapZoneChanged)) { notification in
            if let inZone = notification.object as? Bool {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isInSnapZone = inZone
                }
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

    // MARK: - Standard (horizontal) layout

    private var standardBody: some View {
        ZStack(alignment: showAttachedAppearance ? .bottom : .topLeading) {
            // Background: attached mode (or snap zone preview) has inverse top corners, detached has full rounded corners
            if showAttachedAppearance {
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
                    .stroke(appState.contentColor.opacity(isInSnapZone ? 0.4 : 0.15), lineWidth: isInSnapZone ? 1.0 : 0.5)
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
                        .strokeBorder(appState.contentColor.opacity(0.15), lineWidth: 0.5)
                )
            }

            // In attached mode, content is aligned to the bottom so it appears below the menu bar
            HStack(spacing: islandState == .compact ? Self.compactContentSpacing : 10) {
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
                maxHeight: showAttachedAppearance
                    ? Self.contentHeight(for: islandState, dualLine: appState.dualLineMode, artwork: appState.showArtwork)
                    : .infinity
            )
            .padding(.horizontal, showAttachedAppearance ? Self.earRadius : 0)
            .padding(contentPadding)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: showAttachedAppearance ? .bottom : .topLeading
        )
        .clipShape(
            showAttachedAppearance
                ? AnyShape(AttachedIslandShape(bottomRadius: cornerRadius, inverseRadius: Self.earRadius))
                : AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        // In detached mode, offset the clipped island down so content that
        // overshoots during transitions has transparent space above.
        .padding(.top, showAttachedAppearance ? 0 : Self.transitionOverflowMargin)
    }

    // MARK: - Notch-hugging layout

    private var notchHuggingBody: some View {
        let nw = notchWidth ?? 0
        // Solid island shape: the physical notch is hardware-black and simply
        // overlaps the solid body, so there's no cut-out to punch through
        // (punching one just exposes the desktop behind the window).
        let shape = AttachedIslandShape(bottomRadius: cornerRadius, inverseRadius: Self.earRadius)
        return ZStack(alignment: .top) {
            IslandBackgroundView(
                style: appState.backgroundStyle,
                shape: AnyShape(shape),
                trackId: syncEngine.currentTrackId,
                artworkURL: syncEngine.artworkURL,
                isPlaying: syncEngine.isPlaying,
                solidColor: appState.solidColor
            )
            .overlay(
                shape.stroke(appState.contentColor.opacity(0.15), lineWidth: 0.5)
            )

            NotchHuggingCompactView(
                syncEngine: syncEngine,
                lyricsManager: lyricsManager,
                appState: appState,
                notchWidth: nw,
                notchHeight: notchHeight,
                earWidth: Self.notchEarWidth,
                earInset: Self.earRadius
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(shape)
    }

    // MARK: - Artwork (single persistent instance)

    private var rootFontSize: CGFloat {
        appState.rootFontSize
    }

    private var artworkColumn: some View {
        VStack(spacing: 0) {
            ArtworkView(trackId: syncEngine.currentTrackId, artworkURL: syncEngine.artworkURL, size: artworkSize)
                .padding(.top, islandState == .full ? 8 : 0)

            if islandState == .full {
                sourcePickerBadge
                    .padding(.top, 4)

                // Track info
                VStack(spacing: 2) {
                    if let title = syncEngine.trackTitle {
                        Text(title)
                            .font(.system(size: .rem(0.75, root: rootFontSize), weight: .semibold))
                            .foregroundStyle(appState.contentColor.opacity(0.8))
                            .lineLimit(1)
                    }
                    if let artist = syncEngine.trackArtist {
                        Text(artist)
                            .font(.system(size: .rem(0.6875, root: rootFontSize)))
                            .foregroundStyle(appState.contentColor.opacity(0.5))
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

    @ViewBuilder
    private var sourcePickerBadge: some View {
        if let currentSource = lyricsManager.currentLyrics?.source {
            HStack(spacing: 3) {
                Text(ProviderSettings.displayName(for: currentSource))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .imageScale(.small)
            }
            .font(.system(size: .rem(0.5625, root: rootFontSize), weight: .medium))
            .foregroundStyle(appState.contentColor.opacity(0.3))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(appState.contentColor.opacity(0.08)))
            .overlay {
                // Real NSButton so DynamicIslandPanel's hitTest detects it as NSControl
                NativeButtonOverlay {
                    NotificationCenter.default.post(name: .openLyricsPicker, object: nil)
                }
            }
        }
    }

    private var artworkSize: CGFloat {
        switch islandState {
        case .compact: 28
        case .expanded: 110
        case .full: 200
        }
    }

    private var contentPadding: EdgeInsets {
        switch islandState {
        case .compact:
            EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        case .expanded:
            // In attached mode, move bottom padding to top so the content clears the notch.
            // The bottom padding otherwise pushes the bottom-aligned content up into the menu bar area.
            if showAttachedAppearance {
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
        case .compact: dualLine ? 62 : 38
        case .expanded: artwork ? 140 : 120
        case .full: artwork ? 340 : 340
        }
    }

    /// Width of the compact pill, matching the small Dynamic Island-style footprint.
    static let compactWidth: CGFloat = 220

    /// Horizontal spacing inside the compact pill; kept tight so lyrics remain readable.
    static let compactContentSpacing: CGFloat = 8

    /// Radius of the inverse corner "ears" in attached mode.
    static let earRadius: CGFloat = 10

    /// Width of each ear (artwork / playing indicator) in the notch-hugging layout.
    static let notchEarWidth: CGFloat = 44

    /// Height of the lyrics row below the notch (taller for dual-line mode).
    static func compactLyricsRowHeight(dualLine: Bool) -> CGFloat {
        dualLine ? 44 : 26
    }

    /// Extra top margin in detached mode so content that overshoots during
    /// the SwiftUI transition animation has transparent space to overflow
    /// into instead of being clipped at the window edge.
    static let transitionOverflowMargin: CGFloat = 20

    /// Total vertical content padding for a given state (top + bottom).
    /// In attached mode this is absorbed by the menu-bar extension; in detached
    /// mode it must be added to the panel height explicitly.
    static func verticalPadding(for state: IslandState) -> CGFloat {
        state == .expanded ? 24 : 0
    }

    /// Single source of truth for whether the notch-hugging compact layout
    /// applies: compact state, attached, and a measurable notch. Shared by the
    /// view (`isNotchHugging`) and `size()` so the two can never disagree.
    static func usesNotchHugging(state: IslandState, attached: Bool, notchWidth: CGFloat?) -> Bool {
        state == .compact && attached && (notchWidth ?? 0) > 0
    }

    /// Pure geometry for the notch-hugging compact layout: two ears flanking
    /// the notch on top, a lyrics row below. Independent of NSScreen so it can
    /// be unit-tested.
    static func notchHuggingSize(
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        earWidth: CGFloat,
        lyricsRowHeight: CGFloat
    ) -> NSSize {
        NSSize(width: earWidth * 2 + notchWidth, height: notchHeight + lyricsRowHeight)
    }

    static func size(
        for state: IslandState,
        attached: Bool = false,
        dualLine: Bool = false,
        artwork: Bool = true,
        screen: NSScreen? = nil
    ) -> NSSize {
        // Notch-hugging compact layout: only on notched screens in attached mode.
        if let screen, let nw = screen.notchWidth,
           usesNotchHugging(state: state, attached: attached, notchWidth: nw) {
            return notchHuggingSize(
                notchWidth: nw,
                notchHeight: menuBarHeight(for: screen),
                earWidth: notchEarWidth,
                lyricsRowHeight: compactLyricsRowHeight(dualLine: dualLine)
            )
        }

        let h = contentHeight(for: state, dualLine: dualLine, artwork: artwork)
        let w: CGFloat = switch state {
        case .compact: Self.compactWidth
        case .expanded: artwork ? 450 : 380
        case .full: artwork ? 540 : 400
        }
        if attached {
            // On notch screens menuBarHeight covers the top padding need;
            // on non-notch screens it is 0 so we must add verticalPadding
            // explicitly to avoid clipping the expanded content.
            let topExtra = max(menuBarHeight(for: screen), verticalPadding(for: state))
            return NSSize(width: w, height: h + topExtra)
        }
        return NSSize(width: w, height: h + verticalPadding(for: state) + transitionOverflowMargin)
    }

    private func cycleState() {
        if isAttached {
            // Attached mode: no SwiftUI animation — it would pull the
            // window away from the screen top. Content is bottom-aligned
            // so it stays visually stable as the NSPanel grows downward.
            switch islandState {
            case .compact: islandState = .expanded
            case .expanded: islandState = .full
            case .full: islandState = .compact
            }
        } else {
            withAnimation(.easeOut(duration: 0.35)) {
                switch islandState {
                case .compact: islandState = .expanded
                case .expanded: islandState = .full
                case .full: islandState = .compact
                }
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
            // Same fallback as `refreshNotchGeometry`: an off-screen panel reports
            // no screen, and the two must agree on which screen they describe.
            screen: window.screen ?? NSScreen.main
        ))
    }

    /// Refresh the cached notch geometry from the panel's current screen.
    private func refreshNotchGeometry() {
        let panel = NSApp.windows.first { $0 is DynamicIslandPanel }
        let screen = panel?.screen ?? NSScreen.main
        notchWidth = screen?.notchWidth
        notchHeight = Self.menuBarHeight(for: screen)
    }
}
