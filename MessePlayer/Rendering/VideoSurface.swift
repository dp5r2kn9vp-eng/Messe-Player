import AVFoundation
import SwiftUI

/// Video ohne Bedienelemente, hardwarebeschleunigt über `AVPlayerLayer`.
/// Ohne `onFinish` läuft es nahtlos in Endlosschleife, sonst einmal im getrimmten Bereich und meldet dann Ende oder Fehler.
struct VideoSurface: NSViewRepresentable {
    let url: URL
    var playback = PlaybackSettings()
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
        // Zuerst die Einstellungen, damit ein neues Video am In-Punkt beginnt.
        view.apply(playback)
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
    private var playback = PlaybackSettings()
    private var audioTracks: [AVAssetTrack] = []
    private var trackLoading: Task<Void, Never>?

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
            item.forwardPlaybackEndTime = playback.endTime.map(CMTime.init(seconds:)) ?? .invalid
            player.insert(item, after: nil)
            observeEnd(of: item)
            if playback.startTime > 0 {
                player.seek(to: CMTime(seconds: playback.startTime), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
        loadAudioTracks(of: item, for: url)
        player.play()
    }

    /// Skalierung und Lautstärke; wirkt auch am laufenden Video.
    func apply(_ settings: PlaybackSettings) {
        guard settings != playback else { return }
        let audioChanged = settings.audio != playback.audio || settings.playLength != playback.playLength
            || settings.startTime != playback.startTime
        playback = settings
        (layer as? AVPlayerLayer)?.videoGravity = settings.scaling == .fill ? .resizeAspectFill : .resizeAspect
        if audioChanged { applyAudioMix() }
    }

    func stop() {
        player.pause()
        looper = nil
        player.removeAllItems()
        endObservers.forEach(NotificationCenter.default.removeObserver)
        endObservers = []
        statusObservation = nil
        currentURL = nil
        trackLoading?.cancel()
        audioTracks = []
    }

    private func loadAudioTracks(of item: AVPlayerItem, for url: URL) {
        let asset = item.asset
        trackLoading = Task { [weak self] in
            let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            guard let self, !Task.isCancelled, self.currentURL == url else { return }
            self.audioTracks = tracks
            self.applyAudioMix()
        }
    }

    private func applyAudioMix() {
        let mix = AVAudioMix.cue(tracks: audioTracks, playback: playback)
        player.items().forEach { $0.audioMix = mix }
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
