import SwiftUI

/// Zeigt ein Bild oder Video bildschirmfüllend im Seitenverhältnis (Rest schwarz).
/// Gemeinsamer Renderer für Ausgang und Vorschau.
struct MediaView: View {
    let item: PlayableMedium

    var body: some View {
        ZStack {
            Color.black
            switch item.medium.kind {
            case .image:
                StillImageView(url: item.url)
            case .video:
                VideoSurface(url: item.url)
            }
        }
    }
}

private struct StillImageView: View {
    let url: URL

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            }
        }
        .task(id: url) { image = NSImage(contentsOf: url) }
    }
}
