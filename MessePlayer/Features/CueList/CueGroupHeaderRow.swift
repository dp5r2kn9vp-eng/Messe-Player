import SwiftUI

/// Kopfzeile einer Gruppe: ┌ Name, Modus (Loop ∞ / n-mal), Zufall, Überblendung, Ausgang, Σ Dauer, Zuklappen.
struct CueGroupHeaderRow: View {
    @Binding var group: CueGroup
    let status: CueStatus?
    /// Gemeinsamer Ausgang der Mitglieder; `nil` bei gemischten Ausgängen.
    let outputID: OutputDefinition.ID?
    let outputs: [OutputDefinition]
    let totalDuration: TimeInterval?
    /// Gesetzt nach „Loop beenden“, solange die Gruppe ausläuft.
    var ending: LoopEnding?
    let onSetOutput: (OutputDefinition.ID?) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            CueStatusIcon(status: status).cueColumn(.status)
            GroupBracketTop()
            Text("GRUPPE").font(.caption.weight(.bold)).foregroundStyle(Color.groupBracket)
            TextField("Gruppenname", text: $group.name)
                .textFieldStyle(.plain)
                .font(.headline)
                .frame(minWidth: 100)
            modePicker
            shuffleToggle
            if let ending { endingBadge(ending) }
            Text("Überbl.").font(.caption).foregroundStyle(Color.mutedLight)
            DurationField(seconds: $group.crossfade, range: CueGroup.crossfadeRange)
                .help("Überblendung zwischen den Cues der Gruppe (0 = harter Schnitt)")
            outputPicker
            Text(verbatim: "Σ \(totalDuration.map(TimeFormat.string(from:)) ?? "–")")
                .monospacedDigit()
                .foregroundStyle(Color.mutedLight)
                .help("Summe von Warten und Dauer aller Cues der Gruppe")
            collapseButton
        }
        .frame(minHeight: Theme.minHitSize)
    }

    private var modePicker: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Picker("Modus", selection: Binding(
                get: { group.mode == .loop },
                set: { isLoop in group.mode = isLoop ? .loop : .repeatCount(2) }
            )) {
                Text("Loop ∞").tag(true)
                Text("n-mal").tag(false)
            }
            .labelsHidden()
            .fixedSize()
            if case .repeatCount(let count) = group.mode {
                Stepper(value: Binding(get: { count }, set: { group.mode = .repeatCount($0) }), in: CueGroup.repeatRange) {
                    Text("\(count)×").monospacedDigit()
                }
                .help("Wie oft die Gruppe läuft, danach gilt „Danach“ des letzten Cues")
            }
        }
    }

    private func endingBadge(_ ending: LoopEnding) -> some View {
        Label(ending == .afterPass ? "endet nach Durchlauf" : "endet nach Cue", systemImage: "arrow.turn.down.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brandOrange)
            .help("„Loop beenden“: danach gilt „Danach“ des letzten Cues der Gruppe")
    }

    private var shuffleToggle: some View {
        Toggle(isOn: $group.isShuffled) {
            Image(systemName: "shuffle")
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .accessibilityLabel("Zufällige Reihenfolge")
        .help(group.isShuffled
            ? "Zufällige Reihenfolge an: jeder Durchlauf neu gemischt"
            : "Zufällige Reihenfolge aus: Cues laufen in Listenfolge")
    }

    private var outputPicker: some View {
        Picker("Ausgang", selection: Binding(get: { outputID }, set: onSetOutput)) {
            if outputID == nil {
                Text("gemischt").tag(OutputDefinition.ID?.none)
            }
            ForEach(outputs) { output in
                Text(output.name).tag(OutputDefinition.ID?.some(output.id))
            }
        }
        .labelsHidden()
        .fixedSize()
        .help("Ausgang für alle Cues der Gruppe")
    }

    private var collapseButton: some View {
        Button {
            group.isCollapsed.toggle()
        } label: {
            Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                .frame(width: Theme.minHitSize, height: Theme.minHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(group.isCollapsed ? "Gruppe aufklappen" : "Gruppe zuklappen")
    }
}

/// Oberer Abschluss der Klammer (┌) in der Kopfzeile.
private struct GroupBracketTop: View {
    var body: some View {
        Canvas { context, size in
            let x = size.width / 2
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: size.height / 2))
            path.addLine(to: CGPoint(x: x, y: size.height / 2))
            path.addLine(to: CGPoint(x: x, y: size.height + Theme.Spacing.s))
            context.stroke(path, with: .color(.groupBracket), lineWidth: 2)
        }
        .frame(width: CueBracket.width)
        .frame(maxHeight: .infinity)
    }
}
