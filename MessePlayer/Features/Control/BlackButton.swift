import SwiftUI

/// Schaltet sofort schwarz: „Black alle“ (Taste B) in der Transportleiste, kompakt je Ausgang (⇧B).
struct BlackButton: View {
    var title: LocalizedStringKey = "Black"
    let isActive: Bool
    var isCompact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isActive ? "rectangle.fill" : "rectangle")
                .font(isCompact ? .caption.weight(.semibold) : .headline)
                .frame(minWidth: isCompact ? nil : 88, minHeight: isCompact ? nil : Theme.minHitSize)
        }
        .buttonStyle(BlackButtonStyle(isActive: isActive, isCompact: isCompact))
    }
}

/// „Black alle“: alle Ausgänge, die Cues laufen darunter weiter.
struct BlackAllButton: View {
    @Environment(CueEngine.self) private var engine

    var body: some View {
        BlackButton(title: "Black alle", isActive: engine.isBlack, action: engine.toggleBlack)
            .help("Alle Ausgänge sofort schwarz schalten (Taste B)")
    }
}

private struct BlackButtonStyle: ButtonStyle {
    let isActive: Bool
    let isCompact: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.button)
        configuration.label
            .padding(.horizontal, isCompact ? Theme.Spacing.s : Theme.Spacing.m)
            .padding(.vertical, isCompact ? Theme.Spacing.xs : 0)
            .foregroundStyle(isActive ? Color.brandPaper : Color.brandRed)
            .background(shape.fill(isActive ? Color.brandRed : Color.clear))
            .overlay(shape.stroke(Color.brandRed, lineWidth: isCompact ? 1 : 2))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
