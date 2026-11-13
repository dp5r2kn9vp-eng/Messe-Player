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
