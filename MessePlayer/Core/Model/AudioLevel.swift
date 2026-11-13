import Foundation

/// Lineare Lautstärke-Änderung ab `start` (Sekunden in der Medienzeit) über `duration`.
nonisolated struct VolumeRamp: Equatable {
    let start: TimeInterval
    let duration: TimeInterval
    let from: Double
    let to: Double
}

/// Lautstärke eines Cues mit Fade ein/aus. Rein rechnerisch, damit Grenzen und Rampen testbar sind.
nonisolated struct AudioLevel: Equatable {
    var volume = 1.0
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    var isMuted = false

    /// Ziel-Lautstärke 0…1 nach Stumm und Grenzen.
    var target: Double {
        isMuted ? 0 : volume.clamped(to: Cue.volumeRange)
    }

    /// Fades auf die Spiellänge begrenzt; überlappen sie, werden beide anteilig gekürzt.
    /// Ohne bekannte Länge gibt es keinen Fade aus (das Ende ist dann unbekannt).
    func fades(length: TimeInterval?) -> (in: TimeInterval, out: TimeInterval) {
        let fadeIn = fadeIn.clamped(to: Cue.fadeRange)
        guard let length else { return (fadeIn, 0) }
        let playLength = max(length, 0)
        let fadeOut = fadeOut.clamped(to: Cue.fadeRange)
        let total = fadeIn + fadeOut
        guard total > playLength, total > 0 else { return (fadeIn, fadeOut) }
        let factor = playLength / total
        return (fadeIn * factor, fadeOut * factor)
    }

    /// Rampen in Medienzeit, beginnend bei `start` (In-Punkt) für `length` Sekunden Spielzeit.
    func ramps(from start: TimeInterval = 0, length: TimeInterval?) -> [VolumeRamp] {
        let fades = fades(length: length)
        var ramps: [VolumeRamp] = []
        if fades.in > 0 {
            ramps.append(VolumeRamp(start: start, duration: fades.in, from: 0, to: target))
        }
        if let length, fades.out > 0 {
            ramps.append(VolumeRamp(start: start + max(length, 0) - fades.out, duration: fades.out, from: target, to: 0))
        }
        return ramps
    }

    /// Lautstärke `elapsed` Sekunden nach dem Start.
    func volume(at elapsed: TimeInterval, length: TimeInterval?) -> Double {
        let elapsed = max(elapsed, 0)
        let fades = fades(length: length)
        if fades.in > 0, elapsed < fades.in {
            return target * elapsed / fades.in
        }
        if let length, fades.out > 0 {
            let remaining = max(length, 0) - elapsed
            if remaining <= 0 { return 0 }
            if remaining < fades.out { return target * remaining / fades.out }
        }
        return target
    }
}

nonisolated extension Cue {
    var audioLevel: AudioLevel {
        AudioLevel(volume: volume, fadeIn: fadeIn, fadeOut: fadeOut, isMuted: isMuted)
    }
}
