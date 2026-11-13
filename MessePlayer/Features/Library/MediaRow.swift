import SwiftUI

/// Eine Zeile der Medienbibliothek: Vorschaubild, Name und Typ.
struct MediaRow: View {
    let medium: Medium
    let url: URL?
    /// Läuft gerade auf dem Ausgang.
    let isLive: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            MediaThumbnail(url: url)
                .frame(width: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.button)
                        .stroke(isLive ? Color.brandOrange : .clear, lineWidth: 2)
                }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(medium.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Label(medium.kind.title, systemImage: medium.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
            }
            Spacer(minLength: 0)
            if isLive {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(Color.brandOrange)
                    .help("Läuft gerade auf dem Ausgang")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

extension Medium.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .image: "Bild"
        case .video: "Video"
        }
    }

    var symbolName: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        }
    }
}
