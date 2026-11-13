import SwiftUI

/// Spalten der Cue-Liste in fester Reihenfolge. Name ist flexibel, die übrigen haben feste Breiten.
enum CueColumn: String, CaseIterable, Identifiable {
    case status, number, name, output, wait, duration, followAction, remaining

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .status: "St"
        case .number: "Nr."
        case .name: "Name"
        case .output: "Ausgang"
        case .wait: "Warten"
        case .duration: "Dauer"
        case .followAction: "Danach"
        case .remaining: "Restzeit"
        }
    }

    /// Langer Name für das Spalten-Menü.
    var menuTitle: LocalizedStringKey {
        self == .status ? "Status" : title
    }

    /// `nil` = nimmt den restlichen Platz.
    var width: CGFloat? {
        switch self {
        case .status: 22
        case .number: 44
        case .name: nil
        case .output: 104
        case .wait, .duration: 72
        case .followAction: 152
        case .remaining: 132
        }
    }
}

/// Ausgeblendete Spalten, als Text speicherbar (`@AppStorage`). Standard: alle sichtbar.
struct CueColumnVisibility: RawRepresentable, Equatable {
    private(set) var hidden: Set<CueColumn>

    init(hidden: Set<CueColumn> = []) {
        self.hidden = hidden
    }

    init(rawValue: String) {
        hidden = Set(rawValue.split(separator: ",").compactMap { CueColumn(rawValue: String($0)) })
    }

    var rawValue: String {
        CueColumn.allCases.filter(hidden.contains).map(\.rawValue).joined(separator: ",")
    }

    var visible: [CueColumn] {
        CueColumn.allCases.filter { !hidden.contains($0) }
    }

    func isVisible(_ column: CueColumn) -> Bool {
        !hidden.contains(column)
    }

    mutating func toggle(_ column: CueColumn) {
        if hidden.contains(column) {
            hidden.remove(column)
        } else {
            hidden.insert(column)
        }
    }
}

/// Spaltenköpfe; Rechtsklick blendet Spalten ein und aus.
struct CueColumnHeader: View {
    @Binding var visibility: CueColumnVisibility

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(visibility.visible) { column in
                Text(column.title)
                    .cueColumn(column)
                if column == .status { Spacer().frame(width: CueBracket.width) }
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.mutedLight)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.xs)
        .contextMenu { CueColumnMenu(visibility: $visibility) }
    }
}

/// Umschalter je Spalte, für Kopfzeile und Menü der Liste.
struct CueColumnMenu: View {
    @Binding var visibility: CueColumnVisibility

    var body: some View {
        ForEach(CueColumn.allCases) { column in
            Toggle(column.menuTitle, isOn: Binding(
                get: { visibility.isVisible(column) },
                set: { _ in visibility.toggle(column) }
            ))
        }
    }
}

extension View {
    /// Breite und Ausrichtung einer Spalte, gleich für Kopf und Zeilen.
    func cueColumn(_ column: CueColumn) -> some View {
        frame(
            minWidth: column.width ?? 120,
            maxWidth: column.width ?? .infinity,
            alignment: column == .wait || column == .duration ? .trailing : .leading
        )
    }
}
