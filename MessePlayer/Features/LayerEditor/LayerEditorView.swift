import SwiftUI

/// Editor für die Ebenen eines Eintrags: große Vorschau, Ebenenliste, Eigenschaften.
struct LayerEditorView: View {
    @Binding var entry: Entry
    @Binding var document: ProjectDocument
    let packageURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Layer.ID?
    @State private var animationStart: Date?
    @State private var isPickingImage = false
    @State private var importErrors: [String] = []

    init(entry: Binding<Entry>, document: Binding<ProjectDocument>, packageURL: URL?, selection: Layer.ID? = nil) {
        _entry = entry
        _document = document
        self.packageURL = packageURL
        _selection = State(initialValue: selection)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                LayerCanvas(
                    item: medium.flatMap { document.playable($0, in: packageURL) },
                    layers: document.renderLayers(entry.layers, in: packageURL),
                    selection: $selection,
                    animationStart: animationStart
                ) { id, position in
                    entry.updateLayer(id) { $0.position = position }
                }
                previewControls
            }
            .padding(Theme.Spacing.l)
            .frame(minWidth: 640)
            Divider()
            sidebar.frame(width: 320)
        }
        .frame(minWidth: 1000, minHeight: 560)
        .background(Color.brandDark)
        .fileImporter(isPresented: $isPickingImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { addImage(from: url) }
        }
        .importErrorAlert($importErrors)
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
                    Button("KlangNIVEAU-Logo", systemImage: "seal") { add(.logo()) }
                    Button("Bild aus Datei …", systemImage: "folder") { isPickingImage = true }
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

    private var previewControls: some View {
        HStack(spacing: Theme.Spacing.s) {
            if animationStart == nil {
                Button("Animation ansehen", systemImage: "play.fill") { animationStart = Date() }
            } else {
                Button("Neu starten", systemImage: "arrow.counterclockwise") { animationStart = Date() }
                Button("Bearbeiten", systemImage: "stop.fill") { animationStart = nil }
            }
            Spacer()
            Text(animationStart == nil ? "Ebenen mit der Maus verschieben." : "Vorschau läuft wie auf dem Ausgang.")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
        }
    }

    /// Übernimmt ein Bild in die Bibliothek und legt es direkt als Ebene an.
    private func addImage(from url: URL) {
        let result = document.importMedia(from: [url], at: document.project.media.count)
        importErrors = result.errors.map(\.localizedDescription)
        if let medium = result.added.first {
            add(.image(medium.id))
        }
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
        case .logo: String(localized: "KlangNIVEAU-Logo")
        }
    }

    var symbolName: String {
        switch content {
        case .text: "textformat"
        case .image: "photo"
        case .logo: "seal"
        }
    }
}
