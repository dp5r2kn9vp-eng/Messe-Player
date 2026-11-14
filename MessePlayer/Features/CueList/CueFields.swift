import SwiftUI

/// Ausgangswahl eines Cues; Audio-Cues belegen keinen Ausgang. Gemeinsam für Listenzeile und Inspektor.
struct CueOutputPicker: View {
    let model: CueRowModel
    let onEdit: (CueEdit) -> Void

    var body: some View {
        if model.isAudio {
            Text(verbatim: "–").foregroundStyle(Color.mutedLight)
        } else {
            Picker("Ausgang", selection: Binding(get: { model.cue.outputID }, set: { onEdit(.output($0)) })) {
                ForEach(model.outputs) { output in
                    Text(output.name).tag(OutputDefinition.ID?.some(output.id))
                }
            }
            .labelsHidden()
        }
    }
}

/// Dauer eines Cues: bei Bildern frei, bei Video/Audio nur kürzer als das Medium.
struct CueDurationField: View {
    let model: CueRowModel
    let onEdit: (CueEdit) -> Void
    /// Schrittweite des Steppers; `nil` blendet ihn aus.
    var step: TimeInterval?

    var body: some View {
        if let duration = model.duration, model.cue.mediumID != nil, !model.isMissing {
            DurationField(
                seconds: Binding(get: { duration }, set: { onEdit(.duration($0)) }),
                range: model.medium?.kind == .image ? Cue.stillDurationRange : 0...(24 * 3600),
                step: step
            )
        } else {
            Text(model.duration.map(TimeFormat.string(from:)) ?? "–")
                .monospacedDigit()
                .foregroundStyle(Color.mutedLight)
        }
    }
}

/// Nachwarten eines Cues; nur bei „Mit nächstem starten“ außerhalb von Gruppen bearbeitbar.
struct CuePostWaitField: View {
    let model: CueRowModel
    let onEdit: (CueEdit) -> Void
    var step: TimeInterval?

    var body: some View {
        DurationField(
            seconds: Binding(get: { model.cue.postWait }, set: { onEdit(.postWait($0)) }),
            range: Cue.waitRange,
            step: step
        )
        .disabled(!model.postWaitApplies)
        .help(model.postWaitApplies
            ? "Der nächste Cue startet so viele Sekunden nach diesem"
            : "Wirkt nur bei „Mit nächstem starten“ außerhalb von Gruppen")
    }
}

/// „Danach“ eines Cues; in Loop-Gruppen gesperrt auf „Weiter nach Ende“.
struct CueFollowPicker: View {
    let model: CueRowModel
    let onEdit: (CueEdit) -> Void

    var body: some View {
        Picker("Danach", selection: Binding(
            get: { model.followIsSetByGroup ? .followOnEnd : model.cue.followAction },
            set: { onEdit(.followAction($0)) }
        )) {
            ForEach(FollowAction.allCases, id: \.self) { action in
                Text(action.title).tag(action)
            }
        }
        .labelsHidden()
        .disabled(model.followIsSetByGroup)
        .help(model.followIsSetByGroup
            ? "In einer Gruppe geht es immer weiter nach Ende; der letzte Cue bestimmt, was nach der Gruppe passiert."
            : "Was nach dem Cue passiert")
    }
}

extension Binding where Value == ProjectDocument {
    /// Bindung an einen Cue der Liste (für Editoren wie `LayerEditorView`).
    func cue(_ id: Cue.ID) -> Binding<Cue> {
        Binding<Cue>(
            get: { wrappedValue.project.cue(withID: id) ?? Cue(id: id, number: "") },
            set: { newValue in
                guard let index = wrappedValue.project.cues.firstIndex(where: { $0.id == id }) else { return }
                wrappedValue.project.cues[index] = newValue
            }
        )
    }

    /// Bindung an eine Gruppe der Liste.
    func group(_ id: CueGroup.ID) -> Binding<CueGroup> {
        Binding<CueGroup>(
            get: { wrappedValue.project.groups.first { $0.id == id } ?? .empty(id: id, name: "") },
            set: { newValue in
                guard let index = wrappedValue.project.groups.firstIndex(where: { $0.id == id }) else { return }
                wrappedValue.project.groups[index] = newValue
            }
        )
    }
}

extension ProjectDocument {
    /// Länge von Video/Audio eines Cues, falls bekannt; Bilder haben keine.
    @MainActor func mediaLength(of cue: Cue, in packageURL: URL?, lengths: MediaLengths) -> TimeInterval? {
        guard let medium = cue.mediumID.flatMap(project.medium(withID:)), medium.kind != .image else { return nil }
        return lengths.length(of: media.url(for: medium, in: packageURL))
    }

    /// Alles, was Listenzeile und Inspektor über einen Cue anzeigen.
    func rowModel(_ cue: Cue, mediaLength: TimeInterval?, bracket: GroupBracket? = nil, status: CueStatus? = nil, progress: StepProgress? = nil) -> CueRowModel {
        CueRowModel(
            cue: cue,
            medium: cue.mediumID.flatMap(project.medium(withID:)),
            bracket: bracket,
            status: status,
            progress: progress,
            duration: project.duration(of: cue, mediaLength: mediaLength),
            followIsSetByGroup: project.followActionIsSetByGroup(cue),
            outputs: project.outputs,
            postWaitApplies: project.postWaitApplies(to: cue)
        )
    }
}
