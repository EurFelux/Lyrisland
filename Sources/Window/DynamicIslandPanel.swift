import AppKit
import SwiftUI

/// A borderless, always-on-top floating panel that mimics the iOS Dynamic Island.
final class DynamicIslandPanel: NSPanel {
    private(set) var positionMode: IslandPositionMode

    init(contentView: some View) {
        positionMode = UserDefaults.standard.islandPositionMode
        let initialSize = IslandContentView.size(for: .compact, attached: positionMode == .attached)

        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar + 1
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        animationBehavior = .utilityWindow

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        // macOS 14+: disable the automatic window background that NSHostingView adds
        if #available(macOS 14.0, *) {
            hostingView.sceneBridgingOptions = []
        }

        // Use a plain transparent container to ensure no AppKit background leaks
        let container = NSView(frame: NSRect(origin: .zero, size: initialSize))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.contentView = container

        applyPosition()
    }

    // MARK: - Position Mode

    /// Switch between attached and detached modes.
    func setPositionMode(_ mode: IslandPositionMode) {
        guard mode != positionMode else { return }
        if positionMode == .detached {
            saveDetachedPosition()
        }

        positionMode = mode
        UserDefaults.standard.islandPositionMode = mode
        applyPosition()

        NotificationCenter.default.post(name: .islandPositionModeChanged, object: mode)
    }

    /// Position the panel according to the current mode.
    private func applyPosition() {
        switch positionMode {
        case .attached:
            positionAttachedToMenuBar()
        case .detached:
            if let saved = UserDefaults.standard.islandDetachedPosition {
                setFrameOrigin(saved)
            } else {
                positionBelowMenuBar()
            }
        }
    }

    /// Center the panel horizontally, flush with the top of the screen (no gap).
    private func positionAttachedToMenuBar() {
        guard let screen = screen ?? NSScreen.main else { return }
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.maxY - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Position below the menu bar (default detached fallback).
    private func positionBelowMenuBar() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.maxY - frame.height - 12
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveDetachedPosition() {
        UserDefaults.standard.islandDetachedPosition = frame.origin
    }

    /// Whether the current position is close enough to snap back to attached mode.
    private func isNearAttachedPosition() -> Bool {
        guard let screen = screen ?? NSScreen.main else { return false }
        let distanceFromTop = screen.frame.maxY - frame.maxY
        return distanceFromTop < 20
    }

    // MARK: - Resize

    /// Animate the panel to a new size, keeping the anchor point fixed.
    /// Attached mode: center horizontally on screen, pin to screen top.
    /// Detached mode: keep top-left pinned.
    func animateResize(to newSize: NSSize, duration: TimeInterval = 0.35) {
        let currentFrame = frame

        let newX: CGFloat
        let newY: CGFloat

        if positionMode == .attached, let screen = screen ?? NSScreen.main {
            newX = screen.frame.midX - newSize.width / 2
            newY = screen.frame.maxY - newSize.height
        } else {
            // Detached: keep top-left pinned
            newX = currentFrame.minX
            newY = currentFrame.maxY - newSize.height
        }

        let newFrame = NSRect(origin: NSPoint(x: newX, y: newY), size: newSize)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            self.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Mouse Handling

    private var mouseDownOrigin: NSPoint?
    private var windowOriginOnMouseDown: NSPoint?
    private var isDragUnlocked = false
    private var longPressTimer: Timer?

    /// How long the user must hold before dragging is allowed.
    private static let longPressDuration: TimeInterval = 0.5

    override func mouseDown(with _: NSEvent) {
        mouseDownOrigin = NSEvent.mouseLocation
        windowOriginOnMouseDown = frame.origin

        if positionMode == .detached {
            // Already free-floating — allow immediate dragging
            isDragUnlocked = true
        } else {
            isDragUnlocked = false

            // Start long-press timer — when it fires, haptic feedback signals drag is ready
            longPressTimer = Timer.scheduledTimer(withTimeInterval: Self.longPressDuration, repeats: false) { [weak self] _ in
                guard let self else { return }
                isDragUnlocked = true
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

                // Immediately switch to detached visual state
                if positionMode == .attached {
                    positionMode = .detached
                    UserDefaults.standard.islandPositionMode = .detached
                    NotificationCenter.default.post(name: .islandPositionModeChanged, object: IslandPositionMode.detached)
                }
            }
        }
    }

    override func mouseDragged(with _: NSEvent) {
        guard isDragUnlocked, let origin = mouseDownOrigin, let windowOrigin = windowOriginOnMouseDown else { return }

        let current = NSEvent.mouseLocation
        let newX = windowOrigin.x + (current.x - origin.x)
        let newY = windowOrigin.y + (current.y - origin.y)
        setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    override func mouseUp(with _: NSEvent) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        if let origin = mouseDownOrigin {
            let end = NSEvent.mouseLocation
            let distance = hypot(end.x - origin.x, end.y - origin.y)

            if distance < 5 {
                // Click — toggle island state
                NotificationCenter.default.post(name: .islandTapped, object: nil)
            } else if isDragUnlocked {
                // Drag ended — snap back to attached if near top, otherwise save detached position
                if isNearAttachedPosition() {
                    setPositionMode(.attached)
                } else {
                    saveDetachedPosition()
                }
            }
        }
        mouseDownOrigin = nil
        windowOriginOnMouseDown = nil
        isDragUnlocked = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

extension Notification.Name {
    static let islandTapped = Notification.Name("islandTapped")
    static let islandPositionModeChanged = Notification.Name("islandPositionModeChanged")
    static let islandPositionModeSettingsChanged = Notification.Name("islandPositionModeSettingsChanged")
    static let lyricsOffsetAdjust = Notification.Name("lyricsOffsetAdjust")
    static let lyricsOffsetReset = Notification.Name("lyricsOffsetReset")
}

extension NSScreen {
    /// Whether this screen has a camera notch (e.g. MacBook Pro/Air built-in display).
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }
}
