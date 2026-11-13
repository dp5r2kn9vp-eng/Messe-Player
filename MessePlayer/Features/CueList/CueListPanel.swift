import SwiftUI

/// Hauptansicht: die Cue-Liste mit Gruppenklammern, Bearbeiten in der Zeile und Drag & Drop.
struct CueListPanel: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    /// Auswahl im Medienbereich, für „+ Cue“.
    let librarySelection: Set<Medium.ID>

    @Environment(OutputController.self) private var output
    @Environment(MediaLengths.self) private var mediaLengths
    @AppStorage("cueListColumns") private var columns = CueColumnVisibility()
    @State private var selection = Set<UUID>()
    @State private var importErrors: [String] = []
    @State private var editingLayers: CueReference?

    private var project: Project { document.project }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Cue-Liste", count: project.cues.count) { actions }
            CueColumnHeader(visibility: $columns)
            Divider()
            if project.cues.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .importErrorAlert($importErrors)
        .sheet(item: $editingLayers) { reference in
            LayerEditorView(cue: cueBinding(reference.id), document: $document, packageURL: packageURL)
        }
    }

    // MARK: Kopfzeile

    @ViewBuilder
    private var actions: some View {
        Menu("Spalten", systemImage: "tablecells") {
            CueColumnMenu(visibility: $columns)
        }
        .help("Spalten ein- und ausblenden")
        Button("Cue aus Medien", systemImage: "plus") { addCues(for: project.orderedMediumIDs(librarySelection)) }
            .disabled(librarySelection.isEmpty)
            .help("Für die im Medienbereich ausgewählten Medien Cues anlegen")
        Button("Gruppe bilden", systemImage: "square.stack.3d.down.right") { formGroup() }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(!project.canFormGroup(from: selectedCueIDs))
            .help("Ausgewählte, zusammenhängende Cues zu einer Loop-Gruppe zusammenfassen (⌘G)")
        Button("Gruppe auflösen", systemImage: "square.stack.3d.down.right.fill") { dissolveGroups() }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!canDissolve)
            .help("Gruppe der Auswahl auflösen, die Cues bleiben (⇧⌘G)")
    }

    // MARK: Liste

    private var list: some View {
        let rows = project.listRows
        return ReorderableList(
            items: .constant(rows),
            selection: $selection,
            onInsert: { drops, index in insert(drops, before: index, in: rows) },
            onRemove: remove,
            onMove: { offsets, destination in move(offsets, to: destination, in: rows) },
            primaryAction: start,
            menu: contextMenu,
            row: row
        )
    }

    @ViewBuilder
    private func row(_ row: CueListRow) -> some View {
        switch row {
        case .group(let group):
            CueGroupHeaderRow(
                group: groupBinding(group.id),
                status: project.members(of: group).lazy.compactMap(status).first { $0 != .missing },
                outputID: commonOutput(of: group),
                outputs: project.outputs,
                totalDuration: project.duration(of: group, mediaLength: mediaLength),
                onSetOutput: { document.project.setOutput($0, forGroup: group.id) }
            )
            .moveDisabled(!group.isCollapsed)
        case .cue(let cue, let bracket):
            CueRow(model: rowModel(cue, bracket: bracket), columns: columns) { edit in apply(edit, to: cue.id) }
        }
    }

    @ViewBuilder
    private func contextMenu(_ ids: Set<UUID>) -> some View {
        let cueIDs = project.cueIDs(inSelection: ids)
        Button("Starten", systemImage: "play.fill") { start(ids) }
            .disabled(ids.count != 1)
        Button("Texte & Ebenen bearbeiten …", systemImage: "textformat") { editingLayers = cueIDs.first.map(CueReference.init) }
            .disabled(cueIDs.count != 1)
        Divider()
        Button("Gruppe bilden", systemImage: "square.stack.3d.down.right") { formGroup(cueIDs) }
            .disabled(!project.canFormGroup(from: cueIDs))
        Button("Gruppe auflösen", systemImage: "square.stack.3d.down.right.fill") { document.project.dissolveGroups(touching: ids) }
            .disabled(!canDissolve(ids))
        Divider()
        Button("Entfernen", systemImage: "trash", role: .destructive) { remove(ids) }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Noch keine Cues",
            systemImage: "list.number",
            description: Text("Medien aus dem Medienbereich oder dem Finder hierher ziehen. Bilder stehen 5 s, Videos laufen in voller Länge.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: CueListDrop.self) { drops, _ in
            insert(drops, at: CueDropTarget(offset: 0, groupID: nil))
            return true
        }
    }

    // MARK: Zeilen-Daten

    private func rowModel(_ cue: Cue, bracket: GroupBracket?) -> CueRowModel {
        let medium = cue.mediumID.flatMap(project.medium(withID:))
        let isLive = output.isLive(entry: cue.id)
        return CueRowModel(
            cue: cue,
            medium: medium,
            bracket: bracket,
            status: status(of: cue),
            progress: isLive && !output.state.isBlack ? output.stepProgress : nil,
            duration: project.duration(of: cue, mediaLength: mediaLength(of: cue)),
            followIsSetByGroup: project.followActionIsSetByGroup(cue),
            outputs: project.outputs
        )
    }

    private func status(of cue: Cue) -> CueStatus? {
        if let mediumID = cue.mediumID, project.medium(withID: mediumID) == nil { return .missing }
        guard output.isLive(entry: cue.id) else { return nil }
        return output.state.isPaused ? .paused : .running
    }

    private func mediaLength(of cue: Cue) -> TimeInterval? {
        guard let medium = cue.mediumID.flatMap(project.medium(withID:)), medium.kind != .image else { return nil }
        return mediaLengths.length(of: document.media.url(for: medium, in: packageURL))
    }

    private func commonOutput(of group: CueGroup) -> OutputDefinition.ID? {
        let outputs = Set(project.members(of: group).filter { !project.isAudio($0) }.map(\.outputID))
        return outputs.count == 1 ? outputs.first ?? nil : nil
    }

    private var selectedCueIDs: Set<Cue.ID> {
        project.cueIDs(inSelection: selection)
    }

    private var canDissolve: Bool { canDissolve(selection) }

    private func canDissolve(_ ids: Set<UUID>) -> Bool {
        project.groups.contains { ids.contains($0.id) } || project.cueIDs(inSelection: ids).contains { project.group(containing: $0) != nil }
    }

    // MARK: Bindungen

    private func groupBinding(_ id: CueGroup.ID) -> Binding<CueGroup> {
        Binding(
            get: { document.project.groups.first { $0.id == id } ?? .empty(id: id, name: "") },
            set: { newValue in
                guard let index = document.project.groups.firstIndex(where: { $0.id == id }) else { return }
                document.project.groups[index] = newValue
            }
        )
    }

    private func cueBinding(_ id: Cue.ID) -> Binding<Cue> {
        Binding(
            get: { document.project.cue(withID: id) ?? Cue(id: id, number: "") },
            set: { newValue in
                guard let index = document.project.cues.firstIndex(where: { $0.id == id }) else { return }
                document.project.cues[index] = newValue
            }
        )
    }

    // MARK: Aktionen

    /// Mit Mehrfachauswahl gilt die Eingabe für alle markierten Cues.
    private func apply(_ edit: CueEdit, to id: Cue.ID) {
        let selected = selectedCueIDs
        let targets = edit.appliesToSelection && selected.contains(id) ? selected : [id]
        document.project.apply(edit, to: targets, mediaLength: mediaLength)
    }

    private func move(_ offsets: IndexSet, to destination: Int, in rows: [CueListRow]) {
        let moved = project.cueIDs(inSelection: Set(offsets.map { rows[$0].id }))
        let target = project.dropTarget(in: rows, before: destination, moving: moved)
        document.project.moveCues(moved, toOffset: target.offset, joining: target.groupID)
    }

    private func insert(_ drops: [CueListDrop], before index: Int, in rows: [CueListRow]) {
        insert(drops, at: project.dropTarget(in: rows, before: index))
    }

    /// Medien werden zu Cues; Dateien aus dem Finder landen zusätzlich im Medienbereich.
    private func insert(_ drops: [CueListDrop], at target: CueDropTarget) {
        var mediumIDs: [Medium.ID] = []
        var files: [URL] = []
        for drop in drops {
            switch drop {
            case .medium(let id): mediumIDs.append(id)
            case .file(let url): files.append(url)
            }
        }
        if !files.isEmpty {
            let result = document.importMedia(from: files, at: project.media.count)
            mediumIDs += result.added.map(\.id)
            importErrors = result.errors.map(\.localizedDescription)
        }
        let ids = document.project.insertCues(for: mediumIDs, at: target.offset, joining: target.groupID)
        selection = Set(ids)
    }

    /// Hängt Cues hinter die Auswahl, sonst ans Ende.
    private func addCues(for mediumIDs: [Medium.ID]) {
        let rows = project.listRows
        let after = rows.lastIndex { selection.contains($0.id) }.map { $0 + 1 } ?? rows.count
        insert(mediumIDs.map(CueListDrop.medium), at: project.dropTarget(in: rows, before: after))
    }

    /// Entfernt markierte Cues; ein markierter Gruppenkopf löst nur die Gruppe auf.
    private func remove(_ ids: Set<UUID>) {
        document.project.dissolveGroups(touching: Set(project.groups.map(\.id)).intersection(ids))
        document.project.removeCues(ids)
        selection.subtract(ids)
    }

    private func formGroup(_ ids: Set<Cue.ID>? = nil) {
        guard let groupID = document.project.formGroup(from: ids ?? selectedCueIDs) else { return }
        selection = [groupID]
    }

    private func dissolveGroups() {
        document.project.dissolveGroups(touching: selection)
    }

    /// Startet einen Cue sofort. Bis zur Cue-Engine: Cues in Gruppen starten deren Loop ab diesem Cue.
    private func start(_ ids: Set<UUID>) {
        guard ids.count == 1, let id = ids.first else { return }
        if let group = project.legacyGroups.first(where: { $0.id == id || $0.entries.contains { $0.id == id } }) {
            output.startLoop(document.playlist(for: group, in: packageURL), at: group.id == id ? nil : id)
        } else if let medium = project.cue(withID: id)?.mediumID.flatMap(project.medium(withID:)),
                  let item = document.playable(medium, in: packageURL) {
            output.showSingle(item)
        }
    }
}

/// Macht eine Cue-ID für `.sheet(item:)` nutzbar.
private struct CueReference: Identifiable {
    let id: Cue.ID
}
