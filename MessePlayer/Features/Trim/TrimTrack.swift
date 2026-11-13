import SwiftUI

/// Zeitleiste des Trim-Editors: Filmstreifen bzw. Wellenform, In-/Out-Griffe, Abspielkopf und ziehbare Fade-Dreiecke.
struct TrimTrack<Background: View>: View {
    let length: TimeInterval
    let trim: CueTrim
    /// Wirksame Fades (auf die Dauer begrenzt).
    let fades: (in: TimeInterval, out: TimeInterval)
    let head: TimeInterval
    let onIn: (TimeInterval) -> Void
    let onOut: (TimeInterval) -> Void
    let onFadeIn: (TimeInterval) -> Void
    let onFadeOut: (TimeInterval) -> Void
    let onHead: (TimeInterval) -> Void
    @ViewBuilder let background: () -> Background

    private var handleWidth: CGFloat { 8 }
    private var knobSize: CGFloat { 10 }
    private let space = "trimTrack"

    var body: some View {
        GeometryReader { proxy in
            let scale = TrimScale(length: length, width: proxy.size.width)
            let end = trim.end ?? length
            ZStack(alignment: .topLeading) {
                background()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(.rect(cornerRadius: Theme.Radius.button))
                    .gesture(scrub(scale))
                dimming(scale, end: end, height: proxy.size.height)
                fadeTriangles(scale, end: end, height: proxy.size.height)
                Rectangle()
                    .strokeBorder(Color.brandOrange, lineWidth: 2)
                    .frame(width: max(scale.x(end) - scale.x(trim.inPoint), 1), height: proxy.size.height)
                    .offset(x: scale.x(trim.inPoint))
                    .allowsHitTesting(false)
                playhead(scale, height: proxy.size.height)
                handle(at: scale.x(trim.inPoint), height: proxy.size.height, help: "In-Punkt ziehen") { onIn(scale.time($0)) }
                handle(at: scale.x(end), height: proxy.size.height, help: "Out-Punkt ziehen") { onOut(scale.time($0)) }
            }
            .coordinateSpace(.named(space))
        }
    }

    /// Abgedunkelte Bereiche vor dem In- und hinter dem Out-Punkt.
    private func dimming(_ scale: TrimScale, end: TimeInterval, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().frame(width: scale.x(trim.inPoint), height: height)
            Rectangle().frame(width: max(scale.width - scale.x(end), 0), height: height)
                .offset(x: scale.x(end))
        }
        .foregroundStyle(Color.black.opacity(0.55))
        .allowsHitTesting(false)
    }

    private func fadeTriangles(_ scale: TrimScale, end: TimeInterval, height: CGFloat) -> some View {
        let inEdge = scale.x(trim.inPoint + fades.in)
        let outEdge = scale.x(end - fades.out)
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: scale.x(trim.inPoint), y: 0))
                path.addLine(to: CGPoint(x: scale.x(trim.inPoint), y: height))
                path.addLine(to: CGPoint(x: inEdge, y: 0))
                path.move(to: CGPoint(x: scale.x(end), y: 0))
                path.addLine(to: CGPoint(x: scale.x(end), y: height))
                path.addLine(to: CGPoint(x: outEdge, y: 0))
            }
            .fill(Color.brandOrange.opacity(0.35))
            .allowsHitTesting(false)
            fadeKnob(at: inEdge, help: "Fade ein ziehen") { onFadeIn(scale.time($0) - trim.inPoint) }
            fadeKnob(at: outEdge, help: "Fade aus ziehen") { onFadeOut(end - scale.time($0)) }
        }
    }

    private func fadeKnob(at x: CGFloat, help: LocalizedStringKey, onDrag: @escaping (CGFloat) -> Void) -> some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: knobSize))
            .foregroundStyle(Color.brandOrange)
            .frame(width: Theme.minHitSize, height: Theme.minHitSize)
            .contentShape(.rect)
            .offset(x: x - Theme.minHitSize / 2, y: -Theme.minHitSize / 2)
            .gesture(DragGesture(coordinateSpace: .named(space)).onChanged { onDrag($0.location.x) })
            .help(help)
    }

    private func handle(at x: CGFloat, height: CGFloat, help: LocalizedStringKey, onDrag: @escaping (CGFloat) -> Void) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.brandOrange)
            .frame(width: handleWidth, height: height)
            .frame(width: Theme.minHitSize, height: height)
            .contentShape(.rect)
            .offset(x: x - Theme.minHitSize / 2)
            .gesture(DragGesture(coordinateSpace: .named(space)).onChanged { onDrag($0.location.x) })
            .pointerStyle(.columnResize)
            .help(help)
    }

    private func playhead(_ scale: TrimScale, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.playhead)
            .frame(width: 2, height: height)
            .offset(x: scale.x(head) - 1)
            .allowsHitTesting(false)
    }

    /// Klicken oder Ziehen im Streifen setzt den Abspielkopf.
    private func scrub(_ scale: TrimScale) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(space))
            .onChanged { onHead(scale.time($0.location.x)) }
    }
}

/// Umrechnung zwischen Zeit (Sekunden der Quelle) und x-Position im Streifen.
nonisolated struct TrimScale {
    let length: TimeInterval
    let width: CGFloat

    func x(_ time: TimeInterval) -> CGFloat {
        guard length > 0 else { return 0 }
        return CGFloat(time.clamped(to: 0...length) / length) * width
    }

    func time(_ x: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return (Double(x / width) * length).clamped(to: 0...length)
    }
}
