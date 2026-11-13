import SwiftUI

/// Ein komplettes Bild des Ausgangs: Medium plus Ebenen.
/// Derselbe Baustein dient dem Ausgang und der Editor-Vorschau.
struct FrameView: View {
    let item: PlayableMedium
    let layers: [RenderLayer]
    var onFinish: (() -> Void)?
    var isPaused = false

    var body: some View {
        ZStack {
            MediaView(item: item, onFinish: onFinish, isPaused: isPaused)
            LayerOverlay(layers: layers)
        }
    }
}

/// Zeichnet Ebenen relativ zur verfügbaren Fläche.
struct LayerOverlay: View {
    let layers: [RenderLayer]

    var body: some View {
        GeometryReader { geometry in
            ForEach(layers) { renderLayer in
                LayerView(renderLayer: renderLayer, canvas: geometry.size)
                    .position(
                        x: renderLayer.layer.position.x * geometry.size.width,
                        y: renderLayer.layer.position.y * geometry.size.height
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Eine einzelne Ebene in Pixelmaßen der Fläche `canvas`.
struct LayerView: View {
    let renderLayer: RenderLayer
    let canvas: CGSize

    var body: some View {
        let width = renderLayer.layer.width * canvas.width
        switch renderLayer.layer.content {
        case .text(let style):
            TextLayerView(style: style, scale: canvas.height / TextStyle.referenceHeight)
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

    var body: some View {
        let size = style.size * scale
        Text(style.text)
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
