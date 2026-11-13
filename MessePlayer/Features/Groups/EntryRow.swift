import SwiftUI

/// Ein Eintrag einer Gruppe: Vorschaubild, Name und – bei Bildern – die Standdauer.
struct EntryRow: View {
    @Binding var entry: Entry
    let medium: Medium?
    let url: URL?
    let isLive: Bool
    /// Restzeit, solange dieser Eintrag im Loop sichtbar läuft.
    let progress: StepProgress?
    let onEditLayers: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            content
            if let progress {
                StepProgressBar(progress: progress)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var content: some View {
        HStack(spacing: Theme.Spacing.m) {
            MediaThumbnail(url: url, isLive: isLive)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(medium?.displayName ?? String(localized: "Medium fehlt"))
                    .lineLimit(1)
                    .truncationMode(.middle)
                detail
            }
            Spacer(minLength: Theme.Spacing.s)
            Button(action: onEditLayers) {
                Label(entry.layers.isEmpty ? "Ebenen" : "\(entry.layers.count)", systemImage: "textformat")
            }
            .buttonStyle(.borderless)
            .help("Texte und Ebenen bearbeiten")
            if medium?.kind == .image {
                DurationField(seconds: $entry.imageDuration, range: Entry.durationRange)
                    .help("Wie lange das Bild im Loop stehen bleibt")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch medium?.kind {
        case .image:
            Label("Bild", systemImage: "photo").font(.caption).foregroundStyle(Color.mutedLight)
        case .video:
            Label("Video · läuft komplett", systemImage: "film").font(.caption).foregroundStyle(Color.mutedLight)
        case nil:
            Label("Medium fehlt", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Color.brandRed)
        }
    }
}

/// Eingabe einer Dauer in Sekunden mit Stepper.
struct DurationField: View {
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>
    var step: TimeInterval = 1

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField("Dauer", value: clampedSeconds, format: .number.precision(.fractionLength(0...1)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
            Text("s").foregroundStyle(Color.mutedLight)
            Stepper("Dauer", value: $seconds, in: range, step: step)
                .labelsHidden()
        }
    }

    /// Eingetippte Werte werden auf den erlaubten Bereich begrenzt.
    private var clampedSeconds: Binding<TimeInterval> {
        Binding(get: { seconds }, set: { seconds = $0.clamped(to: range) })
    }
}
