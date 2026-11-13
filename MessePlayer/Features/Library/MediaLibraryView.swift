import SwiftUI

/// Medienbibliothek eines Projekts: Dateien aus dem Finder hineinziehen, sortieren, entfernen,
/// auf dem Ausgang zeigen und Gruppen hinzufügen.
struct MediaLibraryView: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    @Binding var selection: Set<Medium.ID>
    /// `nil`, solange keine Gruppe gewählt ist.
    let onAddToGroup: ((Set<Medium.ID>) -> Void)?

    @Environment(OutputController.self) private var output
    @State private var isPickingFiles = false
    @State private var importErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Medien", count: document.project.media.count) {
                Button("Zur Gruppe hinzufügen", systemImage: "text.badge.plus") { onAddToGroup?(selection) }
                    .disabled(onAddToGroup == nil || selection.isEmpty)
                    .help("Ausgewählte Medien zur gewählten Gruppe hinzufügen")
                Button("Medien hinzufügen", systemImage: "plus") { isPickingFiles = true }
            }
            if document.project.media.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.image, .movie], allowsMultipleSelection: true) { result in
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
            primaryAction: showOnOutput,
            menu: { ids in
                Button("Auf Ausgang zeigen", systemImage: "play.tv") { showOnOutput(ids) }
                    .disabled(ids.count != 1)
                Button("Zur Gruppe hinzufügen", systemImage: "text.badge.plus") { onAddToGroup?(ids) }
                    .disabled(onAddToGroup == nil)
                Button("Entfernen", systemImage: "trash", role: .destructive) { remove(ids) }
            },
            row: { medium in
                MediaRow(
                    medium: medium,
                    url: document.media.url(for: medium, in: packageURL),
                    isLive: output.isLive(medium)
                )
            }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Medien hierher ziehen",
            systemImage: "square.and.arrow.down",
            description: Text("Bilder und Videos aus dem Finder ablegen oder mit + auswählen. Doppelklick zeigt ein Medium auf dem Ausgang.")
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

    /// Zeigt genau ein ausgewähltes Medium dauerhaft auf dem Ausgang.
    private func showOnOutput(_ ids: Set<Medium.ID>) {
        guard ids.count == 1,
              let id = ids.first,
              let medium = document.project.medium(withID: id),
              let item = document.playable(medium, in: packageURL)
        else { return }
        output.showSingle(item)
    }
}
