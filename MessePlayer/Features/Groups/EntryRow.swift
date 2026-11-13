import SwiftUI

/// Ein Eintrag einer Gruppe: Vorschaubild, Name und – bei Bildern – die Standdauer.
struct EntryRow: View {
    @Binding var entry: Entry
    let medium: Medium?
    let url: URL?
    let isLive: Bool

    var body: some View {
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
            if medium?.kind == .image {
                DurationField(seconds: $entry.imageDuration, range: Entry.durationRange)
                    .help("Wie lange das Bild im Loop stehen bleibt")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
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
            TextField("Dauer", value: $seconds, format: .number.precision(.fractionLength(0...1)))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
            Text("s").foregroundStyle(Color.mutedLight)
            Stepper("Dauer", value: $seconds, in: range, step: step)
                .labelsHidden()
        }
    }
}
