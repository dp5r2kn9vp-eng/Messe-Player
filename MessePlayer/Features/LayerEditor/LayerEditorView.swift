import SwiftUI

/// Editor für die Ebenen eines Eintrags: große Vorschau, Ebenenliste, Eigenschaften.
struct LayerEditorView: View {
    @Binding var entry: Entry
    let document: ProjectDocument
    let packageURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Layer.ID?

    init(entry: Binding<Entry>, document: ProjectDocument, packageURL: URL?, selection: Layer.ID? = nil) {
        _entry = entry
        self.document = document
        self.packageURL = packageURL
        _selection = State(initialValue: selection)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                LayerCanvas(
                    item: medium.flatMap { document.playable($0, in: packageURL) },
                    layers: document.renderLayers(entry.layers, in: packageURL),
                    selection: $selection
                ) { id, position in
                    entry.updateLayer(id) { $0.position = position }
                }
                Text("Ebenen in der Vorschau mit der Maus verschieben.")
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
            }
            .padding(Theme.Spacing.l)
            .frame(minWidth: 640)
            Divider()
            sidebar.frame(width: 320)
        }
        .frame(minWidth: 1000, minHeight: 560)
        .background(Color.brandDark)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Ebenen", count: entry.layers.count) {
                Menu("Ebene hinzufügen", systemImage: "plus") {
                    Button("Text", systemImage: "textformat") { add(.text(String(localized: "Neuer Text"))) }
                    Menu("Bild aus Bibliothek") {
                        ForEach(imageMedia) { medium in
                            Button(medium.displayName) { add(.image(medium.id)) }
                        }
                    }
                    .disabled(imageMedia.isEmpty)
                }
                .menuIndicator(.hidden)
            }
            List(selection: $selection) {
                ForEach(entry.layers.reversed()) { layer in
                    Label(layer.title, systemImage: layer.symbolName)
                        .lineLimit(1)
                        .tag(layer.id)
                        .contextMenu {
                            Button("Löschen", systemImage: "trash", role: .destructive) { remove(layer.id) }
                        }
                }
            }
            .frame(height: 140)
            .onDeleteCommand { selection.map(remove) }
            Divider()
            if let layer = selectedLayer {
                LayerInspector(layer: layer, imageMedia: imageMedia)
            } else {
                ContentUnavailableView("Keine Ebene gewählt", systemImage: "square.3.layers.3d", description: Text("Mit + Text oder Bild hinzufügen."))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var medium: Medium? {
        document.project.medium(withID: entry.mediumID)
    }

    private var imageMedia: [Medium] {
        document.project.media.filter { $0.kind == .image }
    }

    private var selectedLayer: Binding<Layer>? {
        guard let id = selection, let current = entry.layers.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { entry.layers.first { $0.id == id } ?? current },
            set: { newValue in entry.updateLayer(id) { $0 = newValue } }
        )
    }

    private func add(_ layer: Layer) {
        entry.layers.append(layer)
        selection = layer.id
    }

    private func remove(_ id: Layer.ID) {
        entry.layers.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }
}

extension Layer {
    var title: String {
        switch content {
        case .text(let style): style.text.isEmpty ? String(localized: "Leerer Text") : style.text
        case .image: String(localized: "Bild")
        }
    }

    var symbolName: String {
        switch content {
        case .text: "textformat"
        case .image: "photo"
        }
    }
}
