import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument
    /// Speicherort des Pakets; `nil`, solange das Projekt noch nie gespeichert wurde.
    let packageURL: URL?

    @Environment(CueEngine.self) private var engine
    @Environment(MediaLengths.self) private var mediaLengths
    @Environment(OutputRouting.self) private var routing
    @Environment(DisplayService.self) private var displays
    @State private var showsOutputSetup = false
    @State private var librarySelection = Set<Medium.ID>()
    @State private var showsFormatNotice = false
    @State private var cueSelection = Set<UUID>()
    @AppStorage("showsMediaPanel") private var showsMedia = true
    @AppStorage("showsInspector") private var showsInspector = true
    /// Kennung dieses Fensters gegenüber der Engine (es gibt eine Engine für alle offenen Projekte).
    @State private var windowID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            ControlHeaderView(showsMedia: $showsMedia, showsInspector: $showsInspector, showsOutputSetup: $showsOutputSetup)
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
                CueListPanel(document: $document, packageURL: packageURL, librarySelection: librarySelection, claim: claimEngine, selection: $cueSelection)
                if showsInspector {
                    Divider()
                    InspectorPanel(document: $document, packageURL: packageURL, selection: cueSelection)
                        .frame(width: 320)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            OutputsBar()
            Divider()
            TransportBar(claim: claimEngine)
        }
        .environment(\.cueNames, cueName)
        .frame(minWidth: 1100, minHeight: 520)
        .onChange(of: currentShow) { updateEngine() }
        .onChange(of: engine.snapshot(projectPath: packageURL?.path)) { saveSession() }
        .task {
            if engine.ownerID == nil { claimEngine() }
            restoreSessionOnce()
            saveSession()
            showsFormatNotice = document.isConvertedFromFormat1
            showsOutputSetup = routing.proposeMissing(
                for: document.project.outputs,
                displays: displays.displays,
                legacyName: SessionStore.legacyOutputDisplayName()
            )
        }
        .sheet(isPresented: $showsOutputSetup) {
            OutputSetupSheet(project: $document.project)
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
    private var currentShow: CueShow {
        document.show(in: packageURL, mediaLength: mediaLengths.length(of:))
    }

    /// Lädt diese Cue-Liste in die Engine, falls gerade ein anderes Fenster sie nutzt.
    private func claimEngine() {
        guard engine.ownerID != windowID else { return }
        engine.load(currentShow, owner: windowID)
    }

    /// Änderungen an der Liste wirken sofort, ohne laufende Cues zu unterbrechen.
    private func updateEngine() {
        guard engine.ownerID == windowID else { return }
        engine.update(currentShow)
    }

    private func cueName(_ id: Cue.ID) -> String {
        guard let cue = document.project.cue(withID: id) else { return "" }
        let name = cue.name.isEmpty ? cue.mediumID.flatMap(document.project.medium(withID:))?.displayName ?? "" : cue.name
        return "\(cue.number) „\(name)“"
    }

    private func saveSession() {
        guard let packageURL, engine.ownerID == windowID else { return }
        SessionStore.save(engine.snapshot(projectPath: packageURL.path))
    }

    private func restoreSessionOnce() {
        guard !didRestoreSession, let packageURL else { return }
        didRestoreSession = true
        guard let snapshot = SessionStore.load(), snapshot.projectPath == packageURL.path else { return }
        claimEngine()
        engine.restore(snapshot)
    }
}

private struct ControlHeaderView: View {
    @Binding var showsMedia: Bool
    @Binding var showsInspector: Bool
    @Binding var showsOutputSetup: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button("Medienbereich", systemImage: "sidebar.left") { showsMedia.toggle() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(showsMedia ? "Medienbereich ausblenden" : "Medienbereich einblenden")
            AppIconImage(size: 36)
            CueViewWordmark(height: 40)
            Spacer()
            Button("Ausgänge …", systemImage: "display.2") { showsOutputSetup = true }
                .help("Ausgänge anlegen und auf diesem Rechner Bildschirmen zuordnen")
            Button("Inspektor", systemImage: "sidebar.right") { showsInspector.toggle() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(showsInspector ? "Inspektor ausblenden" : "Inspektor einblenden")
        }
        .padding(Theme.Spacing.l)
    }
}
