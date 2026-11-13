import SwiftUI

/// Medienbibliothek eines Projekts: Dateien aus dem Finder hineinziehen, sortieren, entfernen.
struct MediaLibraryView: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?

    @State private var selection = Set<Medium.ID>()
    @State private var isPickingFiles = false
    @State private var importErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            header
            if document.project.media.isEmpty {
                emptyState
            } else {
                ReorderableList(items: $document.project.media, selection: $selection, onInsert: importMedia) { medium in
                    MediaRow(medium: medium, url: document.media.url(for: medium, in: packageURL))
                        .contextMenu {
                            Button("Entfernen", role: .destructive) { remove(medium) }
                        }
                }
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
            description: Text("Bilder und Videos aus dem Finder ablegen oder mit + auswählen.")
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

    private func remove(_ medium: Medium) {
        document.project.media.removeAll { $0.id == medium.id }
        selection.remove(medium.id)
    }
}
