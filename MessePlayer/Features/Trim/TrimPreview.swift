import AVFoundation
import Observation

/// Vorhören im Trim-Editor: spielt nur den getrimmten Bereich mit Lautstärke und Fades über `AudioCuePlayer`.
@Observable
final class TrimPreview {
    private(set) var isPlaying = false
    @ObservationIgnored private var player: AudioCuePlayer?

    /// Aktuelle Position in Sekunden der Quelle, solange das Vorhören läuft.
    var position: TimeInterval? {
        isPlaying ? player?.currentTime : nil
    }

    func play(_ url: URL, playback: PlaybackSettings) {
        stop()
        let player = AudioCuePlayer(url: url, playback: playback) { [weak self] in self?.stop() }
        self.player = player
        isPlaying = true
        player.start(atHostTime: CMClockGetTime(CMClockGetHostTimeClock()))
    }

    func stop() {
        player?.stop(fadeOut: 0) {}
        player = nil
        isPlaying = false
    }
}

nonisolated extension PlaybackSettings {
    /// Wiedergabe des getrimmten Bereichs eines Cues mit seiner Lautstärke und seinen Fades.
    static func trimmed(_ cue: Cue, mediaLength: TimeInterval?) -> PlaybackSettings {
        let trim = cue.trim(mediaLength: mediaLength)
        return PlaybackSettings(audio: cue.audioLevel, playLength: trim.duration, startTime: trim.inPoint, endTime: trim.outPoint)
    }
}
