import SwiftUI

/// Eine Zeile der Medienbibliothek: Vorschaubild, Name und Typ.
struct MediaRow: View {
    let medium: Medium
    let url: URL?
    /// Läuft gerade auf dem Ausgang.
    let isLive: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            MediaThumbnail(url: url, isLive: isLive)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(medium.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Label(medium.kind.title, systemImage: medium.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

extension Medium.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .image: "Bild"
        case .video: "Video"
        case .audio: "Audio"
        }
    }

    var symbolName: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        }
    }
}
