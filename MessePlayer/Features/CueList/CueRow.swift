import SwiftUI

/// Zustand eines Cues für die Status-Spalte.
enum CueStatus: Equatable {
    case running
    case paused
    case playhead
    case waiting
    case missing

    var symbolName: String {
        switch self {
        case .running: "play.fill"
        case .paused: "pause.fill"
        case .playhead: "play"
        case .waiting: "hourglass"
        case .missing: "exclamationmark.triangle.fill"
        }
    }

    var help: LocalizedStringKey {
        switch self {
        case .running: "Läuft"
        case .paused: "Pausiert"
        case .playhead: "Als Nächstes (Abspielkopf)"
        case .waiting: "Wartet"
        case .missing: "Medium fehlt"
        }
    }

    var color: Color {
        switch self {
        case .missing: .brandRed
        case .playhead: .playhead
        default: .brandOrange
        }
    }
}

/// Status-Symbol in der Spalte „St“.
struct CueStatusIcon: View {
    let status: CueStatus?

    var body: some View {
        if let status {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.color)
                .help(status.help)
        } else {
            Color.clear
        }
    }
}

/// Alles, was eine Cue-Zeile anzeigt.
struct CueRowModel {
    let cue: Cue
    let medium: Medium?
    let bracket: GroupBracket?
    let status: CueStatus?
    let progress: StepProgress?
    /// Abgeleitete Dauer; `nil`, solange die Medienlänge lädt.
    let duration: TimeInterval?
    /// „Danach“ wird von der Gruppe vorgegeben (Loop) und ist gesperrt.
    let followIsSetByGroup: Bool
    let outputs: [OutputDefinition]
    /// Nachwarten wirkt nur bei „Mit nächstem starten“ außerhalb von Gruppen.
    var postWaitApplies = false
    /// Fade-/Stopp-Cue: Beschreibung wie „Fade: 3 Musik → 30 %“.
    var actionTitle: String?
    var hasMissingTarget = false

    var isMissing: Bool { (cue.mediumID != nil && medium == nil) || hasMissingTarget }
    var isAudio: Bool { medium?.kind == .audio }

    var displayName: String {
        if !cue.name.isEmpty { return cue.name }
        if let actionTitle { return actionTitle }
        if let medium { return medium.displayName }
        return cue.mediumID == nil ? String(localized: "Steuer-Cue") : String(localized: "Medium fehlt")
    }
}

/// Eine Zeile der Cue-Liste; alle Spalten sind direkt in der Zeile bearbeitbar.
struct CueRow: View {
    let model: CueRowModel
    let columns: CueColumnVisibility
    let onEdit: (CueEdit) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(columns.visible) { column in
                cell(column).cueColumn(column)
                if column == .status { CueBracket(bracket: model.bracket) }
            }
        }
        .frame(minHeight: Theme.minHitSize)
    }

    @ViewBuilder
    private func cell(_ column: CueColumn) -> some View {
        let cue = model.cue
        switch column {
        case .status:
            CueStatusIcon(status: model.status)
        case .number:
            TextField("Nr.", text: Binding(get: { cue.number }, set: { onEdit(.number($0)) }))
                .textFieldStyle(.plain)
                .monospacedDigit()
        case .name:
            nameCell
        case .output:
            CueOutputPicker(model: model, onEdit: onEdit)
        case .wait:
            DurationField(seconds: Binding(get: { cue.wait }, set: { onEdit(.wait($0)) }), range: Cue.waitRange)
        case .duration:
            CueDurationField(model: model, onEdit: onEdit)
        case .followAction:
            CueFollowPicker(model: model, onEdit: onEdit)
        case .postWait:
            CuePostWaitField(model: model, onEdit: onEdit)
        case .remaining:
            if let progress = model.progress {
                StepProgressBar(progress: progress)
            }
        }
    }

    private var nameCell: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let symbol = model.cue.action?.symbolName ?? model.medium?.kind.symbolName {
                Image(systemName: symbol).foregroundStyle(Color.mutedLight)
            }
            if let schedule = model.cue.schedule {
                Image(systemName: "clock")
                    .foregroundStyle(Color.brandOrange)
                    .help("Startet um \(schedule.summary)")
            }
            if model.hasMissingTarget {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.brandRed)
                    .help("Ziel fehlt – im Inspektor ein neues Ziel wählen")
            }
            TextField(model.displayName, text: Binding(get: { model.cue.name }, set: { onEdit(.name($0)) }))
                .textFieldStyle(.plain)
                .foregroundStyle(model.isMissing ? Color.brandRed : Color.primary)
        }
    }
}

extension FollowAction {
    var title: LocalizedStringKey {
        switch self {
        case .hold: "Halten"
        case .followOnEnd: "Weiter nach Ende"
        case .continueWithNext: "Mit nächstem starten"
        }
    }
}

/// Gruppenklammer links neben den Mitgliedern: │ bzw. └ beim letzten Cue.
struct CueBracket: View {
    static let width: CGFloat = 12
    let bracket: GroupBracket?

    var body: some View {
        Canvas { context, size in
            guard let bracket else { return }
            let x = size.width / 2
            var path = Path()
            path.move(to: CGPoint(x: x, y: -Theme.Spacing.s))
            if case .last = bracket {
                path.addLine(to: CGPoint(x: x, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            } else {
                path.addLine(to: CGPoint(x: x, y: size.height + Theme.Spacing.s))
            }
            context.stroke(path, with: .color(.groupBracket), lineWidth: 2)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
    }
}
