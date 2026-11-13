import SwiftUI

/// Medienbibliothek eines Projekts: Dateien aus dem Finder hineinziehen, sortieren, entfernen,
/// und als Cues in die Liste übernehmen (Doppelklick, Taste ⏎ oder Ziehen).
struct MediaLibraryView: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    @Binding var selection: Set<Medium.ID>
    /// Legt für die Medien Cues in der Cue-Liste an.
    let onAddCues: (Set<Medium.ID>) -> Void

    @Environment(CueEngine.self) private var engine
    @State private var isPickingFiles = false
    @State private var importErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Medien", count: document.project.media.count) {
                Button("Als Cues hinzufügen", systemImage: "text.badge.plus") { onAddCues(selection) }
                    .disabled(selection.isEmpty)
                    .help("Für die ausgewählten Medien Cues am Ende der Cue-Liste anlegen")
                Button("Medien hinzufügen", systemImage: "plus") { isPickingFiles = true }
            }
            if document.project.media.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.image, .movie, .audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                importMedia(urls, at: document.project.media.count)
            }
        }
        .importErrorAlert($importErrors)
    }

    private var list: some View {
        ReorderableList(
            items: $document.project.media,
            selection: $selection,
            onInsert: importMedia,
            onRemove: remove,
            primaryAction: onAddCues,
            menu: { ids in
                Button("Als Cues hinzufügen", systemImage: "text.badge.plus") { onAddCues(ids) }
                Button("Entfernen", systemImage: "trash", role: .destructive) { remove(ids) }
            },
            row: { medium in
                MediaRow(
                    medium: medium,
                    url: document.media.url(for: medium, in: packageURL),
                    isLive: engine.isShowing(medium.id)
                )
            }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Medien hierher ziehen",
            systemImage: "square.and.arrow.down",
            description: Text("Bilder und Videos aus dem Finder ablegen oder mit + auswählen. Doppelklick legt einen Cue an.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            importMedia(urls, at: 0)
            return true
        }
    }

    private func importMedia(_ urls: [URL], at index: Int) {
        importErrors = document.importMedia(from: urls, at: index).errors.map(\.localizedDescription)
    }

    private func remove(_ ids: Set<Medium.ID>) {
        document.project.removeMedia(ids)
        selection.subtract(ids)
    }
}
