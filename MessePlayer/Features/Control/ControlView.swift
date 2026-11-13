import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument
    /// Speicherort des Pakets; `nil`, solange das Projekt noch nie gespeichert wurde.
    let packageURL: URL?

    @Environment(OutputController.self) private var output
    @Environment(HotkeyService.self) private var hotkeys
    @State private var librarySelection = Set<Medium.ID>()
    @State private var showsFormatNotice = false
    @AppStorage("showsMediaPanel") private var showsMedia = true

    var body: some View {
        VStack(spacing: 0) {
            ControlHeaderView(showsMedia: $showsMedia)
            Divider()
            HStack(spacing: 0) {
                if showsMedia {
                    MediaLibraryView(
                        document: $document,
                        packageURL: packageURL,
                        selection: $librarySelection,
                        onAddCues: { ids in
                            document.project.insertCues(for: document.project.orderedMediumIDs(ids), at: document.project.cues.count)
                        }
                    )
                    .frame(width: 300)
                    Divider()
                }
                CueListPanel(document: $document, packageURL: packageURL, librarySelection: librarySelection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1000, minHeight: 520)
        .onChange(of: document.project.legacyGroups) { refreshRunningLoop() }
        .onChange(of: output.state) { saveSession() }
        .task(id: document.project.legacyGroups.map(\.id)) { registerGroupHotkeys() }
        .task {
            restoreSessionOnce()
            saveSession()
            showsFormatNotice = document.isConvertedFromFormat1
        }
        .alert("Projekt wird ins neue Format umgestellt", isPresented: $showsFormatNotice) {
            Button("OK") {}
        } message: {
            Text("Beim Speichern wird dieses Projekt ins Cue-Format von CueView 2 umgewandelt. Ältere CueView-Versionen können es danach nicht mehr öffnen. Eine Sicherung des alten Stands bleibt als „\(ProjectPackage.v1BackupFileName)“ im Projektpaket.")
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
                let groups = document.wrappedValue.project.legacyGroups
                guard number <= groups.count else { return false }
                output.startLoop(document.wrappedValue.playlist(for: groups[number - 1], in: packageURL))
                return true
            }
        }
    }

    /// Änderungen an der laufenden Gruppe (Reihenfolge, Dauer) wirken sofort.
    private func refreshRunningLoop() {
        guard let id = output.playingGroupID,
              let group = document.project.legacyGroups.first(where: { $0.id == id })
        else { return }
        output.updateLoop(document.playlist(for: group, in: packageURL))
    }
}

private struct ControlHeaderView: View {
    @Binding var showsMedia: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button("Medienbereich", systemImage: "sidebar.left") { showsMedia.toggle() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(showsMedia ? "Medienbereich ausblenden" : "Medienbereich einblenden")
            AppIconImage(size: 36)
            CueViewWordmark(height: 40)
            Spacer()
            DisplayPicker()
            BlackButton()
        }
        .padding(Theme.Spacing.l)
    }
}
