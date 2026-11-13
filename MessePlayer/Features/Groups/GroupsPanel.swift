import SwiftUI

/// Bereich „Gruppen“: links die Gruppen, rechts die Einträge der gewählten Gruppe.
struct GroupsPanel: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    @Binding var selectedGroupID: MediaGroup.ID?

    var body: some View {
        HStack(spacing: 0) {
            GroupListView(groups: $document.project.groups, selection: $selectedGroupID) {
                selectedGroupID = document.project.addGroup()
            }
            .frame(width: 200)
            Divider()
            if let group = selectedGroup {
                GroupEntriesView(document: $document, group: group, packageURL: packageURL)
                    .id(selectedGroupID)
            } else {
                ContentUnavailableView(
                    "Keine Gruppe gewählt",
                    systemImage: "rectangle.stack",
                    description: Text("Links eine Gruppe anlegen oder auswählen.")
                )
            }
        }
    }

    /// Bindung über die ID statt über den Index, damit Löschen und Umsortieren sicher bleiben.
    private var selectedGroup: Binding<MediaGroup>? {
        guard let id = selectedGroupID,
              let current = document.project.groups.first(where: { $0.id == id })
        else { return nil }
        return Binding(
            get: { document.project.groups.first { $0.id == id } ?? current },
            set: { newValue in
                guard let index = document.project.groups.firstIndex(where: { $0.id == id }) else { return }
                document.project.groups[index] = newValue
            }
        )
    }
}
