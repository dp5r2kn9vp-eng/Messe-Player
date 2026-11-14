import AVFoundation

extension AVAudioMix {
    /// Lautstärke und lineare Fade-Rampen eines Cues je Tonspur (Videos mit Ton und Audio-Cues).
    /// `release` ersetzt die Rampen, wenn ein Cue vorzeitig ausgeblendet wird („Stopp alle“).
    static func cue(tracks: [AVAssetTrack], playback: PlaybackSettings, release: VolumeRamp? = nil) -> AVAudioMix {
        let level = playback.audio
        let ramps = release.map { [$0] } ?? level.ramps(from: playback.startTime, length: playback.playLength)
        let startVolume = release?.from ?? (level.fades(length: playback.playLength).in == 0 ? level.target : nil)
        let mix = AVMutableAudioMix()
        mix.inputParameters = tracks.map { track in
            let input = AVMutableAudioMixInputParameters(track: track)
            if let startVolume {
                input.setVolume(Float(startVolume), at: .zero)
            }
            for ramp in ramps {
                guard ramp.duration > 0 else {
                    input.setVolume(Float(ramp.to), at: CMTime(seconds: ramp.start))
                    continue
                }
                input.setVolumeRamp(
                    fromStartVolume: Float(ramp.from),
                    toEndVolume: Float(ramp.to),
                    timeRange: CMTimeRange(start: CMTime(seconds: ramp.start), duration: CMTime(seconds: ramp.duration))
                )
            }
            return input
        }
        return mix
    }
}

extension CMTime {
    init(seconds: TimeInterval) {
        self.init(seconds: seconds, preferredTimescale: 600)
    }
}
