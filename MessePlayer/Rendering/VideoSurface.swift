import AVFoundation
import SwiftUI

/// Video ohne Bedienelemente, hardwarebeschleunigt über `AVPlayerLayer`.
/// Ohne `onFinish` läuft es nahtlos in Endlosschleife, sonst einmal und meldet dann Ende oder Fehler.
struct VideoSurface: NSViewRepresentable {
    let url: URL
    var onFinish: (() -> Void)?
    var isMuted = false
    var isPaused = false

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: PlayerLayerView, context: Context) {
        view.isMuted = isMuted
        view.play(url, onFinish: onFinish)
        view.isPaused = isPaused
    }

    static func dismantleNSView(_ view: PlayerLayerView, coordinator: ()) {
        view.stop()
    }
}

final class PlayerLayerView: NSView {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var currentURL: URL?
    private var onFinish: (() -> Void)?
    private var endObservers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?

    var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    var isPaused = false {
        didSet {
            guard isPaused != oldValue else { return }
            isPaused ? player.pause() : player.play()
        }
    }

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

    func play(_ url: URL, onFinish: (() -> Void)?) {
        self.onFinish = onFinish
        guard url != currentURL else { return }
        stop()
        currentURL = url
        let item = AVPlayerItem(url: url)
        if onFinish == nil {
            looper = AVPlayerLooper(player: player, templateItem: item)
        } else {
            player.insert(item, after: nil)
            observeEnd(of: item)
        }
        player.play()
    }

    func stop() {
        player.pause()
        looper = nil
        player.removeAllItems()
        endObservers.forEach(NotificationCenter.default.removeObserver)
        endObservers = []
        statusObservation = nil
        currentURL = nil
    }

    private func observeEnd(of item: AVPlayerItem) {
        let names = [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification]
        endObservers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onFinish?() }
            }
        }
        statusObservation = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed, let self else { return }
            Task { @MainActor in self.onFinish?() }
        }
    }
}
