import AVFoundation
import SwiftUI

/// Video ohne Bedienelemente, hardwarebeschleunigt über `AVPlayerLayer`, in nahtloser Endlosschleife.
struct VideoSurface: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.play(url)
        return view
    }

    func updateNSView(_ view: PlayerLayerView, context: Context) {
        view.play(url)
    }

    static func dismantleNSView(_ view: PlayerLayerView, coordinator: ()) {
        view.stop()
    }
}

final class PlayerLayerView: NSView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    override init(frame: NSRect) {
        super.init(frame: frame)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        layer = playerLayer
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    func play(_ url: URL) {
        guard url != currentURL else { return }
        currentURL = url
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func stop() {
        player.pause()
        looper = nil
        player.removeAllItems()
        currentURL = nil
    }
}
