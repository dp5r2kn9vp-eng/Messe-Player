import SwiftUI

extension CueAction {
    static let fadeSymbol = "speaker.wave.2.bubble"
    static let stopSymbol = "stop.circle"

    var symbolName: String {
        switch self {
        case .fade: Self.fadeSymbol
        case .stop: Self.stopSymbol
        }
    }
}

extension Project {
    /// Kurzbeschreibung eines Fade-/Stopp-Cues für die Liste.
    func title(of action: CueAction) -> String {
        switch action {
        case .fade(let fade):
            let target = fade.targetCueID.map(cueLabel) ?? String(localized: "kein Ziel")
            var changes: [String] = []
            if let volume = fade.volume { changes.append(String(localized: "Ton \(Int((volume * 100).rounded())) %")) }
            if let opacity = fade.opacity { changes.append(String(localized: "Bild \(Int((opacity * 100).rounded())) %")) }
            if fade.stopsTarget { changes.append(String(localized: "Stopp")) }
            return String(localized: "Fade \(target) → \(changes.joined(separator: ", "))")
        case .stop(let stop):
            switch stop.target {
            case .cue(let id): return String(localized: "Stopp \(cueLabel(id))")
            case .output(let id): return String(localized: "Stopp \(outputs.first { $0.id == id }?.name ?? "?")")
            case nil: return String(localized: "Stopp – kein Ziel")
            }
        }
    }

    /// „Cue 3 Musik“ bzw. „Cue ?“, wenn der Cue fehlt.
    func cueLabel(_ id: Cue.ID) -> String {
        guard let cue = cue(withID: id) else { return String(localized: "Cue ?") }
        let name = cue.name.isEmpty ? cue.mediumID.flatMap(medium(withID:))?.displayName ?? "" : cue.name
        return String(localized: "Cue \(cue.number) \(name)").trimmingCharacters(in: .whitespaces)
    }
}

/// Inspektor eines Fade- oder Stopp-Cues: Ziel, Werte und Dauer.
struct ActionCueEditor: View {
    let action: CueAction
    let cue: Cue
    let project: Project
    let onChange: (CueAction) -> Void

    var body: some View {
        switch action {
        case .fade(let fade): fadeEditor(fade)
        case .stop(let stop): stopEditor(stop)
        }
    }

    /// Cues mit Medium außer diesem; Steuer-Cues sind kein Ziel.
    private var targetCues: [Cue] {
        project.cues.filter { $0.id != cue.id && $0.action == nil && $0.mediumID != nil }
    }

    // MARK: Fade

    @ViewBuilder
    private func fadeEditor(_ fade: FadeAction) -> some View {
        Picker("Ziel", selection: fadeBinding(fade, \.targetCueID)) {
            Text("Kein Ziel").tag(Cue.ID?.none)
            ForEach(targetCues) { target in
                Text(project.cueLabel(target.id)).tag(Cue.ID?.some(target.id))
            }
        }
        levelRow("Lautstärke", value: fadeBinding(fade, \.volume), defaultValue: 0.3)
            .help("Ziel-Lautstärke des Cues; aus = unverändert")
        levelRow("Deckkraft", value: fadeBinding(fade, \.opacity), defaultValue: 0)
            .help("Ziel-Deckkraft des Bildes (0 % = schwarz); aus = unverändert")
        LabeledContent("Dauer") {
            DurationField(seconds: fadeBinding(fade, \.duration), range: FadeAction.durationRange, step: 0.5)
        }
        Toggle("Danach Ziel stoppen", isOn: fadeBinding(fade, \.stopsTarget))
    }

    private func fadeBinding<Value>(_ fade: FadeAction, _ keyPath: WritableKeyPath<FadeAction, Value>) -> Binding<Value> {
        Binding(get: { fade[keyPath: keyPath] }, set: { value in
            var changed = fade
            changed[keyPath: keyPath] = value
            onChange(.fade(changed))
        })
    }

    /// Schalter „ändern“ plus Regler 0–100 %.
    private func levelRow(_ title: LocalizedStringKey, value: Binding<Double?>, defaultValue: Double) -> some View {
        LabeledContent(title) {
            HStack {
                Toggle(title, isOn: Binding(get: { value.wrappedValue != nil }, set: { value.wrappedValue = $0 ? defaultValue : nil }))
                    .labelsHidden()
                if let current = value.wrappedValue {
                    Slider(value: Binding(get: { current * 100 }, set: { value.wrappedValue = $0 / 100 }), in: 0...100, step: 1)
                    Text(verbatim: "\(Int((current * 100).rounded())) %")
                        .monospacedDigit()
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Stopp

    @ViewBuilder
    private func stopEditor(_ stop: StopAction) -> some View {
        Picker("Ziel", selection: Binding(get: { stop.target }, set: { target in
            var changed = stop
            changed.target = target
            onChange(.stop(changed))
        })) {
            Text("Kein Ziel").tag(StopAction.Target?.none)
            Section("Ausgang") {
                ForEach(project.outputs) { output in
                    Text(output.name).tag(StopAction.Target?.some(.output(output.id)))
                }
            }
            Section("Cue") {
                ForEach(targetCues) { target in
                    Text(project.cueLabel(target.id)).tag(StopAction.Target?.some(.cue(target.id)))
                }
            }
        }
        LabeledContent("Ausblenden") {
            DurationField(seconds: Binding(get: { stop.fadeOut }, set: { seconds in
                var changed = stop
                changed.fadeOut = seconds
                onChange(.stop(changed))
            }), range: FadeAction.durationRange, step: 0.5)
        }
        .help("Bild blendet in dieser Zeit auf Schwarz, Ton blendet aus")
    }
}
