import SwiftUI

/// Ein komplettes Bild des Ausgangs: Medium plus Ebenen.
/// Derselbe Baustein dient dem Ausgang und der Editor-Vorschau.
struct FrameView: View {
    let item: PlayableMedium
    let layers: [RenderLayer]
    var playback = PlaybackSettings()
    var onFinish: (() -> Void)?
    var isPaused = false

    /// Jeder Eintrag bekommt eine neue Ansicht und damit einen neuen Startpunkt für Animationen.
    @State private var startedAt = Date()

    var body: some View {
        ZStack {
            MediaView(item: item, playback: playback, onFinish: onFinish, isPaused: isPaused)
            LayerOverlay(layers: layers, startedAt: startedAt)
        }
    }
}

/// Liefert die Zeit seit `startedAt`: fortlaufend, solange sich etwas bewegt, danach eingefroren
/// auf `settlesAfter` – so zeichnet der Ausgang nicht dauerhaft neu. Ohne `startedAt` ist die Zeit `nil` (Endzustand).
struct AnimationClock<Content: View>: View {
    let startedAt: Date?
    /// `nil` = läuft dauerhaft (z. B. Blinken).
    let settlesAfter: TimeInterval?
    @ViewBuilder let content: (TimeInterval?) -> Content

    @State private var isSettled = false

    var body: some View {
        Group {
            if let startedAt, !isSettled {
                TimelineView(.animation) { context in
                    content(context.date.timeIntervalSince(startedAt))
                }
            } else if startedAt != nil, let settlesAfter {
                content(settlesAfter)
            } else {
                content(nil)
            }
        }
        .task(id: startedAt) {
            isSettled = false
            guard let startedAt, let settlesAfter else { return }
            let remaining = settlesAfter - Date().timeIntervalSince(startedAt)
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            if !Task.isCancelled { isSettled = true }
        }
    }
}

/// Zeichnet Ebenen relativ zur verfügbaren Fläche.
struct LayerOverlay: View {
    let layers: [RenderLayer]
    /// `nil` zeigt alle Ebenen im Endzustand ohne Animation.
    var startedAt: Date?

    var body: some View {
        GeometryReader { geometry in
            AnimationClock(
                startedAt: layers.allSatisfy(\.layer.animation.isStatic) ? nil : startedAt,
                settlesAfter: LayerAnimation.settlesAfter(layers.map(\.layer.animation))
            ) { time in
                ForEach(layers) { renderLayer in
                    LayerView(renderLayer: renderLayer, canvas: geometry.size, time: time)
                    .position(
                        x: renderLayer.layer.position.x * geometry.size.width,
                        y: renderLayer.layer.position.y * geometry.size.height
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine einzelne Ebene in Pixelmaßen der Fläche `canvas`.
struct LayerView: View {
    let renderLayer: RenderLayer
    let canvas: CGSize
    /// Zeit seit Beginn des Eintrags; `nil` = Endzustand ohne Animation.
    var time: TimeInterval?

    var body: some View {
        let frame = time.map(renderLayer.layer.animation.frame(at:)) ?? LayerAnimation.Frame()
        content(reveal: frame.reveal)
            .scaleEffect(frame.scale)
            .offset(x: frame.offsetX * canvas.width, y: frame.offsetY * canvas.height)
            .opacity(frame.opacity)
    }

    @ViewBuilder
    private func content(reveal: Double) -> some View {
        let width = renderLayer.layer.width * canvas.width
        switch renderLayer.layer.content {
        case .text(let style):
            TextLayerView(style: style, scale: canvas.height / TextStyle.referenceHeight, reveal: reveal)
                .frame(maxWidth: width)
        case .logo:
            BrandLogo(width: width)
        case .image:
            if let url = renderLayer.imageURL, let image = ImageCache.shared.image(for: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
            }
        }
    }
}

private struct TextLayerView: View {
    let style: TextStyle
    let scale: CGFloat
    /// Sichtbarer Anteil (Schreibmaschine). Der Rest bleibt unsichtbar im Layout, damit nichts springt.
    let reveal: Double

    var body: some View {
        let size = style.size * scale
        Text(revealedText)
            .font(font(size: size))
            .foregroundStyle(Color(style.color))
            .multilineTextAlignment(style.alignment.textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, style.background == nil ? 0 : size * 0.4)
            .padding(.vertical, style.background == nil ? 0 : size * 0.2)
            .background {
                if let background = style.background {
                    RoundedRectangle(cornerRadius: size * 0.2).fill(Color(background))
                }
            }
            .shadow(color: .black.opacity(style.hasShadow ? 0.6 : 0), radius: size * 0.08, y: size * 0.03)
    }

    private var revealedText: AttributedString {
        var text = AttributedString(style.text)
        let visibleCount = Int((Double(style.text.count) * reveal).rounded(.down))
        guard visibleCount < style.text.count else { return text }
        let hiddenStart = text.characters.index(text.startIndex, offsetBy: visibleCount)
        text[hiddenStart...].foregroundColor = .clear
        return text
    }

    private func font(size: CGFloat) -> Font {
        let weight: Font.Weight = style.isBold ? .bold : .regular
        guard let name = style.fontName else { return .system(size: size, weight: weight) }
        return .custom(name, size: size).weight(weight)
    }
}

extension TextStyle.Alignment {
    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

extension Color {
    init(_ color: RGBAColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}
