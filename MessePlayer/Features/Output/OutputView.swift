import SwiftUI

/// Inhalt des Ausgabefensters. Das Logo als Idle-Bild folgt mit dem Branding-Ticket.
struct OutputView: View {
    let output: OutputController

    var body: some View {
        ZStack {
            Color.brandDark
            if output.state.isBlack {
                Color.black
            }
        }
        .ignoresSafeArea()
    }
}
