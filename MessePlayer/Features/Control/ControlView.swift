import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument

    var body: some View {
        VStack(spacing: 0) {
            ControlHeaderView()
            Divider()
            ContentUnavailableView(
                "Noch keine Medien",
                systemImage: "photo.on.rectangle",
                description: Text("Die Medienbibliothek folgt in einem der nächsten Pakete.")
            )
        }
        .frame(minWidth: 720, minHeight: 440)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
    }
}

private struct ControlHeaderView: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Text("Messe-Player")
                .font(.title3.bold())
                .foregroundStyle(Color.brandPaper)
            Spacer()
            DisplayPicker()
            BlackButton()
        }
        .padding(Theme.Spacing.l)
    }
}
