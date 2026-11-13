import Foundation

/// Eine Ebene über einem Eintrag: Text oder Bild. Position und Größe sind relativ zur Bildfläche,
/// damit das Layout auf jedem Bildschirm gleich aussieht.
nonisolated struct Layer: Codable, Equatable, Identifiable {
    enum Content: Codable, Equatable {
        case text(TextStyle)
        case image(Medium.ID)
        /// KlangNIVEAU-Logo aus der App (helle Variante für dunkle Hintergründe).
        case logo
    }

    let id: UUID
    var content: Content
    /// Mittelpunkt der Ebene (0–1 je Achse).
    var position = RelativePoint.center
    /// Breite relativ zur Bildfläche: bei Bildern die Bildbreite, bei Text die maximale Zeilenbreite.
    var width = 0.6

    static func text(_ text: String) -> Layer {
        Layer(id: UUID(), content: .text(TextStyle(text: text)))
    }

    static func image(_ mediumID: Medium.ID) -> Layer {
        Layer(id: UUID(), content: .image(mediumID), width: 0.3)
    }

    /// Vorgefertigte Logo-Ebene: oben mittig, gut lesbar.
    static func logo() -> Layer {
        Layer(id: UUID(), content: .logo, position: RelativePoint(x: 0.5, y: 0.18), width: 0.35)
    }
}

nonisolated struct RelativePoint: Codable, Equatable {
    var x: Double
    var y: Double

    static let center = RelativePoint(x: 0.5, y: 0.5)

    /// Verschoben um einen relativen Versatz, auf der Bildfläche gehalten.
    func offset(dx: Double, dy: Double) -> RelativePoint {
        RelativePoint(x: (x + dx).clamped(to: 0...1), y: (y + dy).clamped(to: 0...1))
    }
}

nonisolated struct TextStyle: Codable, Equatable {
    /// Bezugshöhe für `size`: Auf einem 1080p-Bildschirm entspricht `size` Pixeln.
    static let referenceHeight = 1080.0

    enum Alignment: String, Codable, CaseIterable {
        case leading, center, trailing
    }

    var text: String
    /// Schriftname; `nil` = Systemschrift (SF Pro).
    var fontName: String?
    var size = 72.0
    var isBold = true
    var color = RGBAColor.white
    var alignment = Alignment.center
    var hasShadow = true
    /// Hinterlegte Box; `nil` = keine.
    var background: RGBAColor?
}

/// Farbe unabhängig von SwiftUI/AppKit, damit das Modell speicherbar und testbar bleibt.
nonisolated struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha = 1.0

    static let white = RGBAColor(red: 1, green: 1, blue: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)
}
