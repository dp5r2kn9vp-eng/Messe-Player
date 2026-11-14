import SwiftUI

/// Spalten der Cue-Liste in fester Reihenfolge. Name ist flexibel, die übrigen haben feste Breiten.
enum CueColumn: String, CaseIterable, Identifiable {
    case status, number, name, output, wait, duration, followAction, postWait, remaining

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
        case .postWait: "Nachw."
        case .remaining: "Restzeit"
        }
    }

    /// Langer Name für das Spalten-Menü.
    var menuTitle: LocalizedStringKey {
        switch self {
        case .status: "Status"
        case .postWait: "Nachwarten"
        default: title
        }
    }

    /// `nil` = nimmt den restlichen Platz.
    var width: CGFloat? {
        switch self {
        case .status: 22
        case .number: 44
        case .name: nil
        case .output: 104
        case .wait, .duration, .postWait: 72
        case .followAction: 152
        case .remaining: 132
        }
    }
}

/// Ausgeblendete Spalten, als Text speicherbar (`@AppStorage`).
/// Standard: alle sichtbar außer `hiddenByDefault`; eingeblendete davon stehen mit „+“ im Text.
struct CueColumnVisibility: RawRepresentable, Equatable {
    static let hiddenByDefault: Set<CueColumn> = [.postWait]
    private static let shownMarker = "+"

    private(set) var hidden: Set<CueColumn>

    init(hidden: Set<CueColumn> = CueColumnVisibility.hiddenByDefault) {
        self.hidden = hidden
    }

    init(rawValue: String) {
        let names = rawValue.split(separator: ",").map(String.init)
        let listed = Set(names.compactMap(CueColumn.init(rawValue:)))
        let shown = Set(names.filter { $0.hasPrefix(Self.shownMarker) }.compactMap { CueColumn(rawValue: String($0.dropFirst())) })
        hidden = listed.union(Self.hiddenByDefault.subtracting(shown))
    }

    var rawValue: String {
        CueColumn.allCases.compactMap { column in
            switch (hidden.contains(column), Self.hiddenByDefault.contains(column)) {
            case (true, false): column.rawValue
            case (false, true): Self.shownMarker + column.rawValue
            default: nil
            }
        }
        .joined(separator: ",")
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
            alignment: [.wait, .duration, .postWait].contains(column) ? .trailing : .leading
        )
    }
}
