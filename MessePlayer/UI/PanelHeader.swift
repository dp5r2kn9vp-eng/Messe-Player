import SwiftUI

/// Kopfzeile eines Bereichs im Steuerfenster: Titel, Anzahl, Aktionen rechts.
struct PanelHeader<Actions: View>: View {
    let title: LocalizedStringKey
    let count: Int
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(title).font(.headline)
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
            Spacer()
            actions()
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(Theme.Spacing.m)
    }
}
