import SwiftUI

/// Inhalt des Ausgabefensters: Inhalt mit Überblendung, darüber Black.
struct OutputView: View {
    let output: OutputController

    var body: some View {
        let state = output.state
        ZStack {
            ZStack {
                content(state.content)
                    .id(state.content.transitionID)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: state.transition), value: state.content.transitionID)
            if state.isBlack {
                Color.black
            }
        }
        .ignoresSafeArea()
        .task(id: output.upcoming) { preloadUpcoming() }
    }

    @ViewBuilder
    private func content(_ content: OutputContent) -> some View {
        switch content {
        case .idle:
            IdleView()
        case .single(let item):
            MediaView(item: item, isPaused: output.state.isPaused)
        case .loop(let frame) where frame.isGap:
            Color.black
        case .loop(let frame):
            FrameView(item: frame.item, layers: frame.layers, onFinish: { output.mediaDidFinish(step: frame.step) }, isPaused: output.state.isPaused)
        }
    }

    private func preloadUpcoming() {
        guard let next = output.upcoming, next.medium.kind == .image else { return }
        _ = ImageCache.shared.image(for: next.url)
    }
}

/// Ruhebild des Ausgangs: Logo zentriert auf KlangNIVEAU-Dunkel.
private struct IdleView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.brandDark
                BrandLogo(width: geometry.size.width * 0.4)
            }
        }
    }
}
