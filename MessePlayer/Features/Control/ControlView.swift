import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument
    /// Speicherort des Pakets; `nil`, solange das Projekt noch nie gespeichert wurde.
    let packageURL: URL?

    @State private var librarySelection = Set<Medium.ID>()
    @State private var selectedGroupID: MediaGroup.ID?

    var body: some View {
        VStack(spacing: 0) {
            ControlHeaderView()
            Divider()
            HStack(spacing: 0) {
                MediaLibraryView(
                    document: $document,
                    packageURL: packageURL,
                    selection: $librarySelection,
                    onAddToGroup: selectedGroupID.map { groupID in
                        { ids in document.project.addEntries(for: document.project.orderedMediumIDs(ids), toGroup: groupID) }
                    }
                )
                .frame(width: 320)
                Divider()
                GroupsPanel(document: $document, packageURL: packageURL, selectedGroupID: $selectedGroupID)
            }
        }
        .frame(minWidth: 1000, minHeight: 520)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
    }
}

private struct ControlHeaderView: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Text("Messe-Player")
                .font(.title3.bold())
                .foregroundStyle(Color.brandPaper)
            Spacer()
            DisplayPicker()
            BlackButton()
        }
        .padding(Theme.Spacing.l)
    }
}
