import SwiftUI

/// Schaltet den Ausgang sofort schwarz. Immer sichtbar, auch per Taste B.
struct BlackButton: View {
    @Environment(OutputController.self) private var output

    var body: some View {
        let isBlack = output.state.isBlack
        Button(action: output.toggleBlack) {
            Label("Black", systemImage: isBlack ? "rectangle.fill" : "rectangle")
                .font(.headline)
                .frame(minWidth: 88, minHeight: Theme.minHitSize)
        }
        .buttonStyle(BlackButtonStyle(isActive: isBlack))
        .help("Ausgang sofort schwarz schalten (Taste B)")
    }
}

private struct BlackButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.button)
        configuration.label
            .padding(.horizontal, Theme.Spacing.m)
            .foregroundStyle(isActive ? Color.brandPaper : Color.brandRed)
            .background(shape.fill(isActive ? Color.brandRed : Color.clear))
            .overlay(shape.stroke(Color.brandRed, lineWidth: 2))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
