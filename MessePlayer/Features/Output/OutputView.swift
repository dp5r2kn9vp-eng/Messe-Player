import SwiftUI

/// Inhalt eines Ausgangs mit Überblendung, darüber Black. Gleiche Ansicht im Ausgabefenster und als Vorschau.
struct OutputView: View {
    let engine: CueEngine
    let outputID: OutputDefinition.ID
    /// Nur im Ausgabefenster; `nil` in der Vorschau des Steuerfensters.
    var presentation: OutputPresentation?

    var body: some View {
        ZStack {
            if presentation?.isOnScreen ?? true {
                stage
            } else {
                Color.black
            }
            if let identification = presentation?.identification {
                IdentificationBadge(identification: identification)
            }
        }
        .ignoresSafeArea()
    }

    private var stage: some View {
        let state = engine.state(for: outputID)
        return ZStack {
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
        .task(id: engine.upcoming(on: outputID)) { preloadUpcoming() }
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
        guard let next = engine.upcoming(on: outputID), next.medium.kind == .image else { return }
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

/// Kennzeichnung „Ausgang 2“ mitten auf dem Bildschirm, damit die Zuordnung prüfbar ist.
private struct IdentificationBadge: View {
    let identification: OutputIdentification

    var body: some View {
        GeometryReader { geometry in
            Text(identification.name)
                .font(.system(size: geometry.size.height * 0.12, weight: .bold))
                .foregroundStyle(Color.brandPaper)
                .padding(geometry.size.height * 0.04)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.card * 3)
                        .fill(Color.output(at: identification.colorIndex))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
