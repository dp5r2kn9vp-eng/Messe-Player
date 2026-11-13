import SwiftUI

/// Inhalt des Ausgabefensters. Das Logo als Idle-Bild folgt mit dem Branding-Ticket.
struct OutputView: View {
    let output: OutputController

    var body: some View {
        ZStack {
            content
            if output.state.isBlack {
                Color.black
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var content: some View {
        switch output.state.content {
        case .idle:
            Color.brandDark
        case .single(let item):
            MediaView(item: item)
                .id(item.medium.id)
        }
    }
}
