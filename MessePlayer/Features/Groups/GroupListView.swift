import SwiftUI

/// Liste der Gruppen eines Projekts: anlegen, auswählen, sortieren, löschen.
struct GroupListView: View {
    @Binding var groups: [MediaGroup]
    @Binding var selection: MediaGroup.ID?
    let onAdd: () -> Void

    @Environment(OutputController.self) private var output

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Gruppen", count: groups.count) {
                Button("Gruppe anlegen", systemImage: "plus", action: onAdd)
            }
            List(selection: $selection) {
                ForEach(groups) { group in
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(group.name).lineLimit(1)
                            Text("\(group.entries.count) Einträge")
                                .font(.caption)
                                .foregroundStyle(Color.mutedLight)
                        }
                        Spacer(minLength: 0)
                        if output.playingGroupID == group.id {
                            Image(systemName: "play.fill")
                                .foregroundStyle(Color.brandOrange)
                                .help("Läuft gerade")
                        }
                    }
                    .tag(group.id)
                    .contextMenu {
                        Button("Löschen", systemImage: "trash", role: .destructive) { delete(group.id) }
                    }
                }
                .onMove { groups.move(fromOffsets: $0, toOffset: $1) }
            }
            .onDeleteCommand { selection.map(delete) }
        }
    }

    private func delete(_ id: MediaGroup.ID) {
        groups.removeAll { $0.id == id }
        if selection == id { selection = nil }
    }
}
