import AVFoundation

/// Ein Audio-Cue auf der Systemausgabe: `AVPlayer` mit Lautstärke und Fade-Rampen aus `AudioLevel`.
/// Spielt nur den getrimmten Bereich (`startTime`…`endTime`). Auch für das Vorhören im Trim-Editor.
/// Start und Fortsetzen über eine Host-Zeit, damit gleichzeitig gestartete Cues synchron laufen.
final class AudioCuePlayer {
    private let player: AVPlayer
    private var playback: PlaybackSettings
    private var tracks: [AVAssetTrack] = []
    private var release: VolumeRamp?
    private var onFinish: (() -> Void)?
    private var endObservers: [NSObjectProtocol] = []
    private var statusObservation: NSKeyValueObservation?
    private var trackLoading: Task<Void, Never>?
    private var releaseTask: Task<Void, Never>?
    private var hasStarted = false

    init(url: URL, playback: PlaybackSettings, onFinish: @escaping () -> Void) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        // Sonst wartet der Player auf Puffer und ignoriert die vorgegebene Host-Zeit.
        player.automaticallyWaitsToMinimizeStalling = false
        item.forwardPlaybackEndTime = playback.endTime.map(CMTime.init(seconds:)) ?? .invalid
        self.playback = playback
        self.onFinish = onFinish
        observeEnd(of: item)
        loadTracks(of: item.asset)
    }

    /// Startet bzw. setzt fort, sodass die aktuelle Position zur Host-Zeit `hostTime` erklingt.
    /// Der erste Start beginnt am In-Punkt.
    func start(atHostTime hostTime: CMTime) {
        let time = hasStarted ? CMTime.invalid : CMTime(seconds: playback.startTime)
        hasStarted = true
        player.setRate(1, time: time, atHostTime: hostTime)
    }

    /// Aktuelle Position in Sekunden der Quelle.
    var currentTime: TimeInterval {
        let time = player.currentTime()
        return time.isNumeric ? time.seconds : playback.startTime
    }

    func pause() {
        player.pause()
    }

    /// Lautstärke und Fades; wirkt auch während der Wiedergabe.
    func apply(_ settings: PlaybackSettings) {
        guard settings != playback else { return }
        playback = settings
        applyAudioMix()
    }

    /// Beendet ohne Ende-Meldung; mit `fadeOut` > 0 erst nach einer linearen Ausblendung von der aktuellen Lautstärke.
    func stop(fadeOut: TimeInterval, completion: @escaping () -> Void) {
        onFinish = nil
        guard fadeOut > 0, player.rate != 0 else {
            halt()
            completion()
            return
        }
        let position = currentTime
        let volume = playback.audio.volume(at: position - playback.startTime, length: playback.playLength)
        release = VolumeRamp(start: position, duration: fadeOut, from: volume, to: 0)
        applyAudioMix()
        releaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(fadeOut))
            self?.halt()
            completion()
        }
    }

    private func halt() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        endObservers.forEach(NotificationCenter.default.removeObserver)
        endObservers = []
        statusObservation = nil
        trackLoading?.cancel()
    }

    private func loadTracks(of asset: AVAsset) {
        trackLoading = Task { [weak self] in
            let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
            guard let self, !Task.isCancelled else { return }
            self.tracks = tracks
            self.applyAudioMix()
        }
    }

    private func applyAudioMix() {
        player.currentItem?.audioMix = AVAudioMix.cue(tracks: tracks, playback: playback, release: release)
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
