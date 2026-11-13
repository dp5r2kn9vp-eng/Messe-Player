import AppKit
import SwiftUI

/// Eigenschaften der gewählten Ebene.
struct LayerInspector: View {
    @Binding var layer: Layer
    let imageMedia: [Medium]

    var body: some View {
        Form {
            switch layer.content {
            case .text:
                TextStyleSection(style: textStyle)
            case .image(let mediumID):
                Picker("Bild", selection: imageSource) {
                    ForEach(imageMedia) { Text($0.displayName).tag($0.id) }
                    if !imageMedia.contains(where: { $0.id == mediumID }) {
                        Text("Medium fehlt").tag(mediumID)
                    }
                }
            }
            Section("Platz") {
                LabeledContent("Breite") {
                    Slider(value: $layer.width, in: 0.05...1)
                }
                Button("Mittig ausrichten", systemImage: "align.horizontal.center") {
                    layer.position.x = 0.5
                }
            }
        }
        .formStyle(.grouped)
    }

    private var textStyle: Binding<TextStyle> {
        Binding(
            get: { if case .text(let style) = layer.content { style } else { TextStyle(text: "") } },
            set: { layer.content = .text($0) }
        )
    }

    private var imageSource: Binding<Medium.ID> {
        Binding(
            get: { if case .image(let id) = layer.content { id } else { UUID() } },
            set: { layer.content = .image($0) }
        )
    }
}

private struct TextStyleSection: View {
    @Binding var style: TextStyle

    private static let fontFamilies = NSFontManager.shared.availableFontFamilies

    var body: some View {
        Section("Text") {
            TextField("Text", text: $style.text, axis: .vertical)
                .lineLimit(1...4)
            Picker("Schrift", selection: $style.fontName) {
                Text("System (SF Pro)").tag(String?.none)
                Divider()
                ForEach(Self.fontFamilies, id: \.self) { family in
                    Text(family).tag(Optional(family))
                }
            }
            LabeledContent("Größe") {
                HStack {
                    Slider(value: $style.size, in: 12...300)
                    Text("\(Int(style.size))").monospacedDigit().frame(width: 36, alignment: .trailing)
                }
            }
            Toggle("Fett", isOn: $style.isBold)
            ColorPicker("Farbe", selection: $style.color.color, supportsOpacity: true)
            Picker("Ausrichtung", selection: $style.alignment) {
                Image(systemName: "text.alignleft").tag(TextStyle.Alignment.leading)
                Image(systemName: "text.aligncenter").tag(TextStyle.Alignment.center)
                Image(systemName: "text.alignright").tag(TextStyle.Alignment.trailing)
            }
            .pickerStyle(.segmented)
            Toggle("Schatten", isOn: $style.hasShadow)
            Toggle("Hinterlegte Box", isOn: hasBackground)
            if style.background != nil {
                ColorPicker("Boxfarbe", selection: backgroundColor, supportsOpacity: true)
            }
        }
    }

    private var hasBackground: Binding<Bool> {
        Binding(
            get: { style.background != nil },
            set: { style.background = $0 ? RGBAColor(red: 0, green: 0, blue: 0, alpha: 0.6) : nil }
        )
    }

    private var backgroundColor: Binding<Color> {
        Binding(
            get: { Color(style.background ?? .black) },
            set: { style.background = RGBAColor($0) }
        )
    }
}
