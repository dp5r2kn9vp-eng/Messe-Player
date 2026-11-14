import Foundation

/// Steuer-Cue, der einen anderen, laufenden Cue oder einen Ausgang ändert (statt eigenes Medium zu zeigen).
nonisolated enum CueAction: Codable, Equatable {
    case fade(FadeAction)
    case stop(StopAction)

    /// Wie lange der Steuer-Cue läuft (Blende bzw. Ausblendung).
    var duration: TimeInterval {
        switch self {
        case .fade(let fade): fade.duration
        case .stop(let stop): stop.fadeOut
        }
    }

    /// Ziel-Cue, falls die Aktion einen Cue betrifft.
    var targetCueID: Cue.ID? {
        switch self {
        case .fade(let fade): fade.targetCueID
        case .stop(let stop): if case .cue(let id) = stop.target { id } else { nil }
        }
    }
}

/// Blendet Lautstärke und/oder Deckkraft eines laufenden Cues über `duration` auf neue Werte.
nonisolated struct FadeAction: Codable, Equatable {
    static let durationRange: ClosedRange<TimeInterval> = 0...60

    var targetCueID: Cue.ID?
    /// Ziel-Lautstärke 0…1; `nil` = unverändert.
    var volume: Double? = 0.3 {
        didSet { volume = volume?.clamped(to: Cue.volumeRange) }
    }
    /// Ziel-Deckkraft 0…1; `nil` = unverändert.
    var opacity: Double? {
        didSet { opacity = opacity?.clamped(to: 0...1) }
    }
    var duration: TimeInterval = 3 {
        didSet { duration = duration.clamped(to: Self.durationRange) }
    }
    /// Nach der Blende endet der Ziel-Cue.
    var stopsTarget = false
}

/// Beendet einen Cue oder alles auf einem Ausgang, mit Ausblendung.
nonisolated struct StopAction: Codable, Equatable {
    enum Target: Codable, Hashable {
        case cue(Cue.ID)
        case output(OutputDefinition.ID)
    }

    var target: Target?
    var fadeOut: TimeInterval = 1 {
        didSet { fadeOut = fadeOut.clamped(to: FadeAction.durationRange) }
    }
}
