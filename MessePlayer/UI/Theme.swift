import SwiftUI

/// Gemeinsame Gestaltungs-Tokens laut `docs/STYLEGUIDE.md`.
/// Farben kommen als generierte Asset-Symbole (`Color.brandRed` usw.), nie als Hex im Code.
enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 8
        static let button: CGFloat = 6
    }

    static let minHitSize: CGFloat = 28
}

extension Color {
    /// Klammer und Kopfzeile einer Cue-Gruppe.
    static let groupBracket = Color.brandOrange
    /// Abspielkopf („Als Nächstes“) in der Cue-Liste.
    static let playhead = Color.brandOrange
    /// Tonspur im Show-Zeitstrahl (Audio-Cues haben keinen Ausgang).
    static let audioLane = Color.mutedLight
}

extension Color {
    /// Kennfarben der Ausgänge in Projekt-Reihenfolge (Liste, Kennzeichnung, Ausgangsleiste).
    private static let outputColors: [Color] = [.brandOrange, .outputBlue, .outputGreen, .outputViolet]

    static func output(at index: Int) -> Color {
        outputColors[max(index, 0) % outputColors.count]
    }
}
