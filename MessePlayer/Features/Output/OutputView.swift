import SwiftUI

/// Inhalt des Ausgabefensters: Inhalt mit Überblendung, darüber Black.
struct OutputView: View {
    let engine: CueEngine

    var body: some View {
        let state = engine.state
        ZStack {
            ZStack {
                content(state)
                    .id(state.content.transitionID)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: state.transition), value: state.content.transitionID)
            if state.isBlack {
                Color.black
            }
        }
        .ignoresSafeArea()
        .task(id: engine.upcoming) { preloadUpcoming() }
    }

    @ViewBuilder
    private func content(_ state: OutputState) -> some View {
        switch state.content {
        case .idle:
            IdleView()
        case .blank:
            Color.black
        case .cue(let frame):
            FrameView(
                item: frame.item,
                layers: frame.layers,
                onFinish: { engine.mediaDidFinish(cueID: frame.cueID, step: frame.step) },
                isPaused: state.isPaused
            )
        }
    }

    private func preloadUpcoming() {
        guard let next = engine.upcoming, next.medium.kind == .image else { return }
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
