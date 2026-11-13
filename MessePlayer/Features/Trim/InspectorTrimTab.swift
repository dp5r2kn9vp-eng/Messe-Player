import SwiftUI

/// Trim: In-/Out-Punkt per Griff oder Eingabe, Abspielkopf, Vorhören des getrimmten Bereichs und Fade-Rampen.
/// Video zeigt einen Filmstreifen, Audio eine Wellenform.
struct InspectorTrimTab: View {
    let context: InspectorContext
    /// Datei des ersten Cues; `nil`, wenn das Medium fehlt.
    let url: URL?
    let mediaLength: TimeInterval?

    @State private var preview = TrimPreview()
    @State private var head: TimeInterval = 0

    private var cue: Cue { context.cue }

    var body: some View {
        if let url, let length = mediaLength, length > 0 {
            editor(url: url, length: length)
                .onDisappear { preview.stop() }
        } else {
            Text(url == nil ? "Medium fehlt" : "Länge wird ermittelt …")
                .foregroundStyle(Color.mutedLight)
        }
    }

    @ViewBuilder
    private func editor(url: URL, length: TimeInterval) -> some View {
        let trim = cue.trim(mediaLength: length)
        let duration = trim.duration ?? length
        LabeledContent("Original", value: TimeFormat.string(from: length))
        TimelineView(.animation(paused: !preview.isPlaying)) { _ in
            track(url: url, length: length, trim: trim, duration: duration)
        }
        .frame(height: 64)
        .padding(.top, Theme.Spacing.m)
        LabeledContent("Kopf", value: TimeFormat.string(from: preview.position ?? head))
        pointRow("In", value: trim.inPoint, length: length, edit: CueEdit.inPoint)
        pointRow("Out", value: trim.end ?? length, length: length, edit: CueEdit.outPoint)
        LabeledContent("Dauer = Out − In") {
            Text(TimeFormat.string(from: duration)).monospacedDigit()
        }
        HStack {
            Button(preview.isPlaying ? "Stopp" : "Vorhören", systemImage: preview.isPlaying ? "stop.fill" : "play.fill") {
                togglePreview(url: url, length: length)
            }
            .help("Spielt nur den getrimmten Bereich mit Lautstärke und Fades")
            Spacer()
            Button("Zurücksetzen", systemImage: "arrow.uturn.backward") { context.onEdit(.resetTrim) }
                .disabled(!trim.isTrimmed)
                .help("Volle Länge des Mediums")
        }
        Text(caption(fades: cue.audioLevel.fades(length: duration)))
            .font(.caption)
            .foregroundStyle(Color.mutedLight)
    }

    private func track(url: URL, length: TimeInterval, trim: CueTrim, duration: TimeInterval) -> some View {
        TrimTrack(
            length: length,
            trim: trim,
            fades: cue.audioLevel.fades(length: duration),
            head: preview.position ?? head,
            onIn: { context.onEdit(.inPoint($0)) },
            onOut: { context.onEdit(.outPoint($0)) },
            onFadeIn: { context.onEdit(.fadeIn(min($0, duration))) },
            onFadeOut: { context.onEdit(.fadeOut(min($0, duration))) },
            onHead: { head = $0 }
        ) {
            if context.model.medium?.kind == .video {
                FilmstripView(url: url, length: length)
            } else {
                WaveformView(url: url)
            }
        }
    }

    private func pointRow(_ title: LocalizedStringKey, value: TimeInterval, length: TimeInterval, edit: @escaping (TimeInterval) -> CueEdit) -> some View {
        LabeledContent(title) {
            HStack(spacing: Theme.Spacing.s) {
                DurationField(seconds: context.binding(value, edit), range: 0...length, width: 72)
                Button("Setzen auf Kopf", systemImage: "arrow.down.to.line") { context.onEdit(edit(preview.position ?? head)) }
                    .labelStyle(.iconOnly)
                    .help("Auf die Position des Abspielkopfs setzen")
            }
        }
    }

    private func togglePreview(url: URL, length: TimeInterval) {
        if preview.isPlaying {
            preview.stop()
        } else {
            preview.play(url, playback: .trimmed(cue, mediaLength: length))
        }
    }

    private func caption(fades: (in: TimeInterval, out: TimeInterval)) -> String {
        let fadeText = String(localized: "Fade ein \(TimeFormat.string(from: fades.in)) · aus \(TimeFormat.string(from: fades.out)) – Dreiecke ziehen")
        guard context.isMultiple else { return fadeText }
        return fadeText + "\n" + String(localized: "In/Out gelten nur für den ersten Cue, Zurücksetzen und Fades für alle markierten.")
    }
}
