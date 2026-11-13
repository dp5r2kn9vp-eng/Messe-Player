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
            Color.brandDark
        case .single(let item):
            MediaView(item: item)
        case .loop(let frame) where frame.isGap:
            Color.black
        case .loop(let frame):
            MediaView(item: frame.item) { output.mediaDidFinish(step: frame.step) }
        }
    }

    private func preloadUpcoming() {
        guard let next = output.upcoming, next.medium.kind == .image else { return }
        _ = ImageCache.shared.image(for: next.url)
    }
}
