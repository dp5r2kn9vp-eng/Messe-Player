import SwiftUI

/// Zeigt ein Bild oder Video bildschirmfüllend im Seitenverhältnis (Rest schwarz).
/// Gemeinsamer Renderer für Ausgang und Vorschau.
struct MediaView: View {
    let item: PlayableMedium
    /// `nil`: Video in Endlosschleife (Einzelanzeige). Sonst einmal abspielen und danach – oder bei einem Fehler – melden.
    var onFinish: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black
            switch item.medium.kind {
            case .image:
                StillImageView(url: item.url, onFailure: onFinish)
            case .video:
                VideoSurface(url: item.url, onFinish: onFinish)
            }
        }
    }
}

private struct StillImageView: View {
    let url: URL
    let onFailure: (() -> Void)?

    var body: some View {
        if let image = ImageCache.shared.image(for: url) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Color.black.onAppear { onFailure?() }
        }
    }
}
