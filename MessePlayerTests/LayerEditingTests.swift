import Foundation
import SwiftUI
import Testing
@testable import MessePlayer

@MainActor
struct LayerEditingTests {
    @Test func updatesOnlyTheGivenLayer() {
        var entry = Cue(number: "1")
        let a = Layer.text("A"), b = Layer.text("B")
        entry.layers = [a, b]
        entry.updateLayer(b.id) { $0.position = RelativePoint(x: 0.1, y: 0.9) }
        #expect(entry.layers[0] == a)
        #expect(entry.layers[1].position == RelativePoint(x: 0.1, y: 0.9))
    }

    @Test func draggingKeepsLayerOnCanvas() {
        let moved = RelativePoint(x: 0.9, y: 0.1).offset(dx: 0.5, dy: -0.5)
        #expect(moved == RelativePoint(x: 1, y: 0))
    }

    @Test func colorPickerRoundTripKeepsValues() {
        let color = RGBAColor(red: 0.93, green: 0.11, blue: 0.15, alpha: 0.8)
        let back = RGBAColor(Color(color))
        #expect(abs(back.red - color.red) < 0.01)
        #expect(abs(back.alpha - color.alpha) < 0.01)
    }
}
