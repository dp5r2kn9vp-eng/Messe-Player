import SwiftUI

/// Medienbibliothek eines Projekts: Dateien aus dem Finder hineinziehen, sortieren, entfernen.
struct MediaLibraryView: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?

    @Environment(OutputController.self) private var output

    @State private var selection = Set<Medium.ID>()
    @State private var isPickingFiles = false
    @State private var importErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            if document.project.media.isEmpty {
                emptyState
            } else {
                ReorderableList(
                    items: $document.project.media,
                    selection: $selection,
                    onInsert: importMedia,
                    primaryAction: showOnOutput,
                    menu: { ids in
                        Button("Auf Ausgang zeigen", systemImage: "play.tv") { showOnOutput(ids) }
                            .disabled(ids.count != 1)
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
        }
        .fileImporter(isPresented: $isPickingFiles, allowedContentTypes: [.image, .movie], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                importMedia(urls, at: document.project.media.count)
            }
        }
        .alert("Nicht alle Dateien wurden übernommen", isPresented: hasImportErrors) {
            Button("OK") {}
        } message: {
            Text(importErrors.joined(separator: "\n"))
        }
    }

    private var header: some View {
        HStack {
            Text("Medien").font(.headline)
            Text("\(document.project.media.count)")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
            Spacer()
            Button("Medien hinzufügen", systemImage: "plus") { isPickingFiles = true }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(Theme.Spacing.m)
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

    private var hasImportErrors: Binding<Bool> {
        Binding(get: { !importErrors.isEmpty }, set: { if !$0 { importErrors = [] } })
    }

    private func importMedia(_ urls: [URL], at index: Int) {
        importErrors = document.importMedia(from: urls, at: index).map(\.localizedDescription)
    }

    private func remove(_ ids: Set<Medium.ID>) {
        document.project.media.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    /// Zeigt genau ein ausgewähltes Medium dauerhaft auf dem Ausgang.
    private func showOnOutput(_ ids: Set<Medium.ID>) {
        guard ids.count == 1,
              let medium = document.project.media.first(where: { ids.contains($0.id) }),
              let url = document.media.url(for: medium, in: packageURL)
        else { return }
        output.showSingle(PlayableMedium(medium: medium, url: url))
    }
}
