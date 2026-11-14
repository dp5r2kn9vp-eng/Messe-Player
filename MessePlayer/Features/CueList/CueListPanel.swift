import SwiftUI

/// Hauptansicht: die Cue-Liste mit Gruppenklammern, Bearbeiten in der Zeile und Drag & Drop.
struct CueListPanel: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    /// Auswahl im Medienbereich, für „+ Cue“.
    let librarySelection: Set<Medium.ID>
    /// Lädt diese Cue-Liste in die Engine, bevor gestartet wird.
    let claim: () -> Void
    /// Auswahl der Liste; der Inspektor zeigt sie.
    @Binding var selection: Set<UUID>
    /// Messe-Modus: Liste gesperrt – Klick setzt den Abspielkopf, Doppelklick startet, sonst nichts.
    var isLocked = false

    @Environment(CueEngine.self) private var engine
    @Environment(MediaLengths.self) private var mediaLengths
    @AppStorage("cueListColumns") private var columns = CueColumnVisibility()
    @State private var importErrors: [String] = []
    @State private var editingLayers: CueReference?

    private var project: Project { document.project }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Cue-Liste", count: project.cues.count) {
                if !isLocked { actions }
            }
            CueColumnHeader(visibility: $columns)
            Divider()
            if project.cues.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .importErrorAlert($importErrors)
        .onChange(of: selection) { followSelectionWithPlayhead() }
        .sheet(item: $editingLayers) { reference in
            LayerEditorView(cue: $document.cue(reference.id), document: $document, packageURL: packageURL)
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
            isEditable: !isLocked,
            menu: contextMenu,
            row: row
        )
    }

    private func row(_ row: CueListRow) -> some View {
        editableRow(row)
            .allowsHitTesting(!isLocked)
    }

    @ViewBuilder
    private func editableRow(_ row: CueListRow) -> some View {
        switch row {
        case .group(let group):
            CueGroupHeaderRow(
                group: $document.group(group.id),
                status: project.members(of: group).lazy.compactMap(status).first { $0 != .missing },
                outputID: commonOutput(of: group),
                outputs: project.outputs,
                totalDuration: project.duration(of: group, mediaLength: mediaLength),
                ending: isEngineShowingThisList ? engine.loopEnding(of: group.id) : nil,
                onSetOutput: { document.project.setOutput($0, forGroup: group.id) }
            )
            .moveDisabled(!group.isCollapsed)
        case .cue(let cue, let bracket):
            CueRow(model: rowModel(cue, bracket: bracket), columns: columns) { edit in apply(edit, to: cue.id) }
        }
    }

    @ViewBuilder
    private func contextMenu(_ ids: Set<UUID>) -> some View {
        Button("Starten", systemImage: "play.fill") { start(ids) }
            .disabled(ids.count != 1)
        Button("Abspielkopf hierher", systemImage: "play") { setPlayhead(ids) }
            .disabled(ids.count != 1)
        if !isLocked { editingMenu(ids) }
    }

    @ViewBuilder
    private func editingMenu(_ ids: Set<UUID>) -> some View {
        let cueIDs = project.cueIDs(inSelection: ids)
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
            guard !isLocked else { return false }
            insert(drops, at: CueDropTarget(offset: 0, groupID: nil))
            return true
        }
    }

    // MARK: Zeilen-Daten

    private func rowModel(_ cue: Cue, bracket: GroupBracket?) -> CueRowModel {
        document.rowModel(
            cue,
            mediaLength: mediaLength(of: cue),
            bracket: bracket,
            status: status(of: cue),
            progress: isEngineShowingThisList ? engine.running[cue.id]?.progress : nil
        )
    }

    private func status(of cue: Cue) -> CueStatus? {
        if let mediumID = cue.mediumID, project.medium(withID: mediumID) == nil { return .missing }
        guard isEngineShowingThisList else { return nil }
        if let running = engine.running[cue.id] {
            if engine.isPaused { return .paused }
            return running.phase == .waiting ? .waiting : .running
        }
        return engine.playheadID == cue.id ? .playhead : nil
    }

    /// Die Engine zeigt Status nur für die Liste, die sie gerade abspielt.
    private var isEngineShowingThisList: Bool {
        engine.show.cues.map(\.id) == project.cues.map(\.id)
    }

    private func mediaLength(of cue: Cue) -> TimeInterval? {
        document.mediaLength(of: cue, in: packageURL, lengths: mediaLengths)
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

    /// Startet einen Cue bzw. eine Gruppe (Kopfzeile) sofort.
    private func start(_ ids: Set<UUID>) {
        guard ids.count == 1, let id = ids.first else { return }
        claim()
        if let group = project.groups.first(where: { $0.id == id }), let first = project.members(of: group).first {
            engine.start(first.id)
        } else {
            engine.start(id)
        }
    }

    /// Klick auf eine Zeile setzt den Abspielkopf, ohne zu starten.
    private func followSelectionWithPlayhead() {
        guard selection.count == 1, isEngineShowingThisList else { return }
        setPlayhead(selection)
    }

    private func setPlayhead(_ ids: Set<UUID>) {
        guard let id = ids.first else { return }
        claim()
        let group = project.groups.first { $0.id == id }
        engine.setPlayhead(group.flatMap { project.members(of: $0).first?.id } ?? id)
    }
}

/// Macht eine Cue-ID für `.sheet(item:)` nutzbar.
private struct CueReference: Identifiable {
    let id: Cue.ID
}
