import SwiftUI

/// Renders the island background based on the selected style.
struct IslandBackgroundView: View {
    let style: BackgroundStyle
    let shape: AnyShape
    let trackId: String?
    let artworkURL: URL?
    let isPlaying: Bool
    var solidColor: Color = .init(white: 0.08)

    @State private var albumColors: [Color] = []

    var body: some View {
        switch style {
        case .solid:
            shape.fill(solidColor)

        case .albumGradient:
            albumGradientBackground

        case .vibrancy:
            VisualEffectBackground()
                .clipShape(shape)

        case .animatedGradient:
            animatedGradientBackground
        }
    }

    // MARK: - Album Gradient

    private var albumGradientBackground: some View {
        Group {
            if albumColors.count >= 2 {
                LinearGradient(
                    colors: albumColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
            } else {
                shape.fill(Color(white: 0.08))
            }
        }
        .task(id: trackId) {
            await loadAlbumColors()
        }
        .animation(.easeInOut(duration: 1.0), value: albumColors.map(\.description))
    }

    private func loadAlbumColors() async {
        guard let trackId, let artworkURL else {
            albumColors = []
            return
        }
        guard let image = await ArtworkCache.shared.image(for: trackId, url: artworkURL) else {
            albumColors = []
            return
        }
        let colors = await ColorExtractor.shared.extractColors(from: image, trackId: trackId)
        albumColors = colors
    }

    // MARK: - Animated Gradient

    /// Hue wanders via layered sine waves with irrational frequency ratios,
    /// so the pattern never repeats perceptibly.
    private var animatedGradientBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !isPlaying)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Three hues drifting at incommensurate rates
            let h1 = Self.wanderingHue(t: t, base: 0.0, speeds: (0.12, 0.07, 0.03))
            let h2 = Self.wanderingHue(t: t, base: 0.33, speeds: (0.10, 0.05, 0.02))
            let h3 = Self.wanderingHue(t: t, base: 0.66, speeds: (0.08, 0.06, 0.04))

            let rotation = t * 0.4

            AngularGradient(
                colors: [
                    Color(hue: h1, saturation: 0.55, brightness: 0.15),
                    Color(hue: h2, saturation: 0.50, brightness: 0.13),
                    Color(hue: h3, saturation: 0.45, brightness: 0.17),
                    Color(hue: h1, saturation: 0.55, brightness: 0.15),
                ],
                center: .center,
                startAngle: .radians(rotation),
                endAngle: .radians(rotation + .pi * 2)
            )
            .clipShape(shape)
        }
    }

    /// Produce a slowly drifting hue in [0, 1] by summing sine waves at different speeds.
    private static func wanderingHue(t: Double, base: Double, speeds: (Double, Double, Double)) -> Double {
        let raw = base
            + 0.25 * sin(t * speeds.0)
            + 0.15 * sin(t * speeds.1)
            + 0.10 * sin(t * speeds.2)
        return raw - floor(raw) // wrap to [0, 1]
    }
}

// MARK: - Visual Effect NSViewRepresentable

/// Wraps NSVisualEffectView for use in SwiftUI, providing a vibrancy/blur effect.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
