import AppKit
import SwiftUI

extension RGBAColor {
    /// Übernimmt eine Farbe aus dem Farbwähler (umgerechnet nach sRGB).
    init(_ color: Color) {
        let srgb = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent, alpha: srgb.alphaComponent)
    }
}

extension Binding where Value == RGBAColor {
    /// Bindung für `ColorPicker`.
    var color: Binding<Color> {
        Binding<Color>(get: { Color(wrappedValue) }, set: { wrappedValue = RGBAColor($0) })
    }
}
