import AVFoundation

/// Was die Cue-Engine zum Abspielen eines Audio-Cues übergibt.
struct AudioCuePlayback: Equatable {
    let cueID: Cue.ID
    let item: PlayableMedium
    /// Kennung des Starts für `CueEngine.mediaDidFinish`.
    let step: Int
    var playback = PlaybackSettings()
}

/// Ton der Audio-Cues. Austauschbar, damit Engine-Tests ohne echte Wiedergabe laufen.
protocol AudioCueOutput: AnyObject {
    /// Startet einen Audio-Cue; ein laufender Player desselben Cues endet vorher hart.
    func play(_ playback: AudioCuePlayback, onFinish: @escaping () -> Void)
    func update(_ cueID: Cue.ID, playback: PlaybackSettings)
    /// Beendet einen Audio-Cue; `fadeOut` 0 = harter Schnitt.
    func stop(_ cueID: Cue.ID, fadeOut: TimeInterval)
    /// Hält alle Audio-Cues gemeinsam an bzw. setzt sie zur selben Host-Zeit fort.
    func setPaused(_ paused: Bool)
}

/// Audio-Cues auf der Systemausgabe (Geräteauswahl folgt bei Bedarf).
/// Im selben Durchlauf gestartete oder fortgesetzte Player teilen sich eine Host-Zeit und laufen dadurch synchron.
final class AudioCuePlayers: AudioCueOutput {
    private var players: [Cue.ID: AudioCuePlayer] = [:]
    /// Ausblendende Player bis zum Ende ihres Fade-outs.
    private var releasing: [ObjectIdentifier: AudioCuePlayer] = [:]
    private var isPaused = false
    private var batchHostTime: CMTime?

    func play(_ playback: AudioCuePlayback, onFinish: @escaping () -> Void) {
        stop(playback.cueID, fadeOut: 0)
        let player = AudioCuePlayer(url: playback.item.url, playback: playback.playback, onFinish: onFinish)
        players[playback.cueID] = player
        if !isPaused {
            player.start(atHostTime: sharedHostTime())
        }
    }

    func update(_ cueID: Cue.ID, playback: PlaybackSettings) {
        players[cueID]?.apply(playback)
    }

    func stop(_ cueID: Cue.ID, fadeOut: TimeInterval) {
        guard let player = players.removeValue(forKey: cueID) else { return }
        let key = ObjectIdentifier(player)
        releasing[key] = player
        player.stop(fadeOut: isPaused ? 0 : fadeOut) { [weak self] in
            self?.releasing[key] = nil
        }
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            players.values.forEach { $0.pause() }
        } else {
            let hostTime = sharedHostTime()
            players.values.forEach { $0.start(atHostTime: hostTime) }
        }
    }

    /// Eine Host-Zeit je Durchlauf der Hauptschleife (z. B. alle Cues einer Kette „Mit nächstem starten“).
    private func sharedHostTime() -> CMTime {
        if let batchHostTime { return batchHostTime }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        batchHostTime = now
        Task { [weak self] in self?.batchHostTime = nil }
        return now
    }
}
