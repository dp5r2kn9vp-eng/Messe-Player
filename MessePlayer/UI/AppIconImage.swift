import SwiftUI

/// Das CueView-App-Icon als Bild, z. B. in Kopfzeile, Info- und Willkommensfenster.
struct AppIconImage: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// CueView-Wortmarke in gewünschter Höhe.
struct CueViewWordmark: View {
    let height: CGFloat

    var body: some View {
        Image(.cueViewWordmark)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("CueView")
    }
}
