import SwiftUI

/// Einträge einer Gruppe: umbenennen, sortieren, Dauer einstellen, Dateien aus dem Finder aufnehmen.
struct GroupEntriesView: View {
    @Binding var document: ProjectDocument
    @Binding var group: MediaGroup
    let packageURL: URL?

    @Environment(OutputController.self) private var output
    @State private var selection = Set<Entry.ID>()
    @State private var importErrors: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                TextField("Gruppenname", text: $group.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                Text("\(group.entries.count) Einträge")
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
                Spacer()
                Text("Überblendung").font(.caption).foregroundStyle(Color.mutedLight)
                DurationField(seconds: $group.crossfade, range: MediaGroup.crossfadeRange, step: 0.5)
                    .help("Überblendung zwischen den Einträgen (0 = harter Schnitt)")
                playButton
            }
            .padding(Theme.Spacing.m)
            if group.entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .importErrorAlert($importErrors)
    }

    @ViewBuilder
    private var playButton: some View {
        if output.playingGroupID == group.id {
            Button("Stopp", systemImage: "stop.fill") { output.stop() }
        } else {
            Button("Starten", systemImage: "play.fill") { startLoop() }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandOrange)
                .disabled(group.entries.isEmpty)
        }
    }

    private var list: some View {
        ReorderableList(
            items: $group.entries,
            selection: $selection,
            onInsert: importFiles,
            onRemove: remove,
            primaryAction: { ids in startLoop(at: ids.first) },
            menu: { ids in
                Button("Loop ab hier starten", systemImage: "play.fill") { startLoop(at: ids.first) }
                    .disabled(ids.count != 1)
                Button("Einzeln auf Ausgang zeigen", systemImage: "play.tv") { showOnOutput(ids) }
                    .disabled(ids.count != 1)
                Button("Aus Gruppe entfernen", systemImage: "minus.circle", role: .destructive) { remove(ids) }
            },
            row: { entry in
                let medium = document.project.medium(withID: entry.mediumID)
                EntryRow(
                    entry: binding(for: entry.id),
                    medium: medium,
                    url: medium.flatMap { document.media.url(for: $0, in: packageURL) },
                    isLive: output.isLive(entry: entry.id)
                )
            }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Gruppe ist leer",
            systemImage: "rectangle.stack.badge.plus",
            description: Text("Medien links auswählen und zur Gruppe hinzufügen oder Dateien aus dem Finder hierher ziehen.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            importFiles(urls, at: 0)
            return true
        }
    }

    private func binding(for id: Entry.ID) -> Binding<Entry> {
        Binding(
            get: { group.entries.first { $0.id == id } ?? Entry(id: id, mediumID: UUID()) },
            set: { newValue in
                guard let index = group.entries.firstIndex(where: { $0.id == id }) else { return }
                group.entries[index] = newValue
            }
        )
    }

    /// Dateien aus dem Finder landen in der Bibliothek und zugleich an der Drop-Position der Gruppe.
    private func importFiles(_ urls: [URL], at index: Int) {
        let result = document.importMedia(from: urls, at: document.project.media.count)
        document.project.addEntries(for: result.added.map(\.id), toGroup: group.id, at: index)
        importErrors = result.errors.map(\.localizedDescription)
    }

    private func remove(_ ids: Set<Entry.ID>) {
        group.entries.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }

    private func startLoop(at entryID: Entry.ID? = nil) {
        output.startLoop(document.playlist(for: group, in: packageURL), at: entryID)
    }

    private func showOnOutput(_ ids: Set<Entry.ID>) {
        guard ids.count == 1,
              let entry = group.entries.first(where: { ids.contains($0.id) }),
              let medium = document.project.medium(withID: entry.mediumID),
              let item = document.playable(medium, in: packageURL)
        else { return }
        output.showSingle(item)
    }
}
