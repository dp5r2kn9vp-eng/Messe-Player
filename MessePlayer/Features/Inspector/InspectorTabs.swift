import SwiftUI

/// Zeit & Ablauf: Warten, Dauer, Danach, Bild-Blenden.
struct InspectorTimingTab: View {
    let context: InspectorContext

    var body: some View {
        let cue = context.cue
        LabeledContent("Warten") {
            DurationField(seconds: context.binding(cue.wait, CueEdit.wait), range: Cue.waitRange, step: 0.5)
        }
        LabeledContent("Dauer") {
            CueDurationField(model: context.model, onEdit: context.onEdit, step: 0.5)
        }
        LabeledContent("Danach") {
            CueFollowPicker(model: context.model, onEdit: context.onEdit)
        }
        if !context.model.isAudio {
            LabeledContent("Blende ein") {
                DurationField(seconds: context.binding(cue.blendIn, CueEdit.blendIn), range: Cue.blendRange, step: 0.1)
            }
            .help("Überblendung beim Erscheinen (außerhalb von Gruppen; dort gilt die Überblendung der Gruppe)")
            LabeledContent("Blende aus") {
                DurationField(seconds: context.binding(cue.blendOut, CueEdit.blendOut), range: Cue.blendRange, step: 0.1)
            }
            .help("Blende auf Schwarz, wenn ein Video endet")
        }
    }
}

/// Ausgang & Bild: Ausgang, Skalierung, Überblendung der Gruppe.
struct InspectorPictureTab: View {
    let context: InspectorContext
    /// Gruppe des ersten Cues; `nil` außerhalb von Gruppen.
    let group: Binding<CueGroup>?

    var body: some View {
        LabeledContent("Ausgang") {
            CueOutputPicker(model: context.model, onEdit: context.onEdit)
        }
        Picker("Skalierung", selection: context.binding(context.cue.scaling, CueEdit.scaling)) {
            ForEach(ContentScaling.allCases, id: \.self) { scaling in
                Text(scaling.title).tag(scaling)
            }
        }
        if let group {
            LabeledContent("Überblendung") {
                DurationField(seconds: group.crossfade, range: CueGroup.crossfadeRange, step: 0.1)
            }
            .help("Überblendung zwischen den Cues von „\(group.wrappedValue.name)“")
        } else {
            LabeledContent("Überblendung") {
                Text("Nur in Gruppen, sonst „Blende ein“")
                    .foregroundStyle(Color.mutedLight)
            }
        }
    }
}

/// Audio: Lautstärke 0–100 %, Fade ein/aus als lineare Rampe, Stumm.
struct InspectorAudioTab: View {
    let context: InspectorContext

    var body: some View {
        let cue = context.cue
        LabeledContent("Lautstärke") {
            HStack(spacing: Theme.Spacing.s) {
                Slider(value: percent, in: 0...100, step: 1)
                Text(verbatim: "\(Int(percent.wrappedValue.rounded())) %")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .disabled(cue.isMuted)
        }
        LabeledContent("Fade ein") {
            DurationField(seconds: context.binding(cue.fadeIn, CueEdit.fadeIn), range: Cue.fadeRange, step: 0.5)
        }
        LabeledContent("Fade aus") {
            DurationField(seconds: context.binding(cue.fadeOut, CueEdit.fadeOut), range: Cue.fadeRange, step: 0.5)
        }
        Toggle("Stumm", isOn: context.binding(cue.isMuted, CueEdit.muted))
        if context.model.isAudio {
            Text("Audio-Cues sind hörbar, sobald die Audio-Wiedergabe da ist; die Werte gelten dann schon.")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
        }
    }

    private var percent: Binding<Double> {
        Binding(
            get: { context.cue.volume * 100 },
            set: { context.onEdit(.volume($0 / 100)) }
        )
    }
}

/// Texte & Ebenen: öffnet den bestehenden Ebenen-Editor für den Cue.
struct InspectorLayersTab: View {
    @Binding var cue: Cue
    @Binding var document: ProjectDocument
    let packageURL: URL?

    @State private var isEditing = false

    var body: some View {
        LabeledContent("Ebenen") {
            Text(verbatim: "\(cue.layers.count)").monospacedDigit()
        }
        LabeledContent("Animiert") {
            Text(verbatim: "\(cue.layers.filter { !$0.animation.isStatic }.count)").monospacedDigit()
        }
        Button("Texte & Ebenen bearbeiten …", systemImage: "textformat") { isEditing = true }
            .sheet(isPresented: $isEditing) {
                LayerEditorView(cue: $cue, document: $document, packageURL: packageURL)
            }
    }
}
