import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument
    /// Speicherort des Pakets; `nil`, solange das Projekt noch nie gespeichert wurde.
    let packageURL: URL?

    @Environment(OutputController.self) private var output
    @Environment(HotkeyService.self) private var hotkeys
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 520)
        .onChange(of: document.project.groups) { refreshRunningLoop() }
        .onChange(of: output.state) { saveSession() }
        .task(id: document.project.groups.map(\.id)) { registerGroupHotkeys() }
        .task {
            restoreSessionOnce()
            saveSession()
        }
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
    }
}

/// Stellt den letzten Zustand nur einmal pro App-Start wieder her.
@MainActor private var didRestoreSession = false

extension ControlView {
    private func saveSession() {
        guard let packageURL else { return }
        SessionStore.save(output.snapshot(projectPath: packageURL.path))
    }

    private func restoreSessionOnce() {
        guard !didRestoreSession, let packageURL else { return }
        didRestoreSession = true
        guard let snapshot = SessionStore.load(), snapshot.projectPath == packageURL.path else { return }
        output.restore(snapshot, from: document, packageURL: packageURL)
    }

    /// Tasten 1–9 starten die Gruppen in ihrer Reihenfolge.
    private func registerGroupHotkeys() {
        for number in 1...9 {
            hotkeys.register(String(number)) { [document = $document, packageURL, output] in
                let groups = document.wrappedValue.project.groups
                guard number <= groups.count else { return false }
                output.startLoop(document.wrappedValue.playlist(for: groups[number - 1], in: packageURL))
                return true
            }
        }
    }

    /// Änderungen an der laufenden Gruppe (Reihenfolge, Dauer) wirken sofort.
    private func refreshRunningLoop() {
        guard let id = output.playingGroupID,
              let group = document.project.groups.first(where: { $0.id == id })
        else { return }
        output.updateLoop(document.playlist(for: group, in: packageURL))
    }
}

private struct ControlHeaderView: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            AppIconImage(size: 36)
            CueViewWordmark(height: 40)
            Spacer()
            DisplayPicker()
            BlackButton()
        }
        .padding(Theme.Spacing.l)
    }
}
