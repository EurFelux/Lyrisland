import SwiftUI

/// A text view that scrolls horizontally (marquee/ticker) when the text is too wide for its container.
/// When text fits, it displays statically. When it overflows, it scrolls left with pauses at each end.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color

    var scrollEnabled: Bool = true
    var loops: Bool = true
    var speed: Double = 30 // points per second
    var startDelay: Double = 1.5
    var endDelay: Double = 1.5
    var fadeWidth: CGFloat = 16

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animationPhase: AnimationPhase = .idle

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    private var needsScroll: Bool {
        scrollEnabled && overflow > 0
    }

    var body: some View {
        // Use a truncated Text as the layout driver for intrinsic height + width negotiation,
        // then overlay the actual (possibly scrolling) content on top.
        Text(text)
            .font(font)
            .lineLimit(1)
            .hidden()
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset)
                        .onAppear { containerWidth = geo.size.width }
                        .onChange(of: geo.size.width) { _, newWidth in containerWidth = newWidth }
                        .onChange(of: text) { _, _ in resetAnimation() }
                        .onChange(of: containerWidth) { _, _ in resetAnimation() }
                        .onChange(of: textWidth) { _, _ in
                            if animationPhase == .idle, needsScroll {
                                animationPhase = .start
                            }
                        }
                        .background(
                            Text(text)
                                .font(font)
                                .fixedSize(horizontal: true, vertical: false)
                                .hidden()
                                .background(GeometryReader { textGeo in
                                    Color.clear
                                        .onAppear { textWidth = textGeo.size.width }
                                        .onChange(of: text) { _, _ in
                                            textWidth = textGeo.size.width
                                        }
                                })
                        )
                }
                .clipped()
                .mask(fadeMask)
            }
            .task(id: animationPhase) {
                await runAnimationPhase()
            }
    }

    @ViewBuilder
    private var fadeMask: some View {
        if needsScroll {
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: offset < 0 ? fadeWidth : 0)

                Rectangle().fill(.white)

                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: offset > -overflow ? fadeWidth : 0)
            }
        } else {
            Rectangle().fill(.white)
        }
    }

    private func resetAnimation() {
        offset = 0
        animationPhase = .idle
    }

    @MainActor
    private func runAnimationPhase() async {
        switch animationPhase {
        case .idle:
            // Wait for GeometryReader to measure, then kick off if needed.
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            if needsScroll {
                animationPhase = .start
            }

        case .start:
            guard needsScroll else { return }
            try? await Task.sleep(for: .seconds(startDelay))
            guard !Task.isCancelled else { return }
            animationPhase = .scrolling

        case .scrolling:
            let duration = overflow / speed
            withAnimation(.linear(duration: duration)) {
                offset = -overflow
            }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            animationPhase = .end

        case .end:
            try? await Task.sleep(for: .seconds(endDelay))
            guard !Task.isCancelled else { return }
            if loops {
                offset = 0
                animationPhase = .idle
            }
        }
    }

    private enum AnimationPhase: Equatable {
        case idle
        case start
        case scrolling
        case end
    }
}
