import SwiftUI

/// Zeigt ein Bild oder Video im Seitenverhältnis: eingepasst (Rest schwarz) oder füllend (beschnitten).
/// Gemeinsamer Renderer für Ausgang und Vorschau.
struct MediaView: View {
    let item: PlayableMedium
    var playback = PlaybackSettings()
    /// `nil`: Video in Endlosschleife (Einzelanzeige). Sonst einmal abspielen und danach – oder bei einem Fehler – melden.
    var onFinish: (() -> Void)?
    /// Vorschauen laufen stumm, damit der Ton nur vom Ausgang kommt.
    var isMuted = false
    var isPaused = false

    var body: some View {
        ZStack {
            Color.black
            switch item.medium.kind {
            case .image:
                StillImageView(url: item.url, scaling: playback.scaling, onFailure: onFinish)
            case .video:
                VideoSurface(url: item.url, playback: playback, onFinish: onFinish, isMuted: isMuted, isPaused: isPaused)
            case .audio:
                // Audio hat kein Bild; Wiedergabe übernimmt später der Audio-Player der Cue-Engine.
                EmptyView()
            }
        }
        .clipped()
    }
}

private struct StillImageView: View {
    let url: URL
    let scaling: ContentScaling
    let onFailure: (() -> Void)?

    var body: some View {
        if let image = ImageCache.shared.image(for: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: scaling == .fill ? .fill : .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.black.onAppear { onFailure?() }
        }
    }
}
