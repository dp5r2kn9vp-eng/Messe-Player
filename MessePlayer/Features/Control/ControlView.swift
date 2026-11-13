import SwiftUI

/// Steuerfenster eines Projekts auf dem MacBook.
struct ControlView: View {
    @Binding var document: ProjectDocument
    /// Speicherort des Pakets; `nil`, solange das Projekt noch nie gespeichert wurde.
    let packageURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            ControlHeaderView()
            Divider()
            HStack(spacing: 0) {
                MediaLibraryView(document: $document, packageURL: packageURL)
                    .frame(width: 320)
                Divider()
                ContentUnavailableView(
                    "Gruppen",
                    systemImage: "rectangle.stack",
                    description: Text("Gruppen und Loops folgen in einem der nächsten Pakete.")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 480)
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
