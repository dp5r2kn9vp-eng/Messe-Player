import Foundation

/// In- und Out-Punkt eines Video-/Audio-Cues in Sekunden der Quelle. Rein rechnerisch, damit Grenzen testbar sind.
/// `outPoint == nil` heißt „bis Medienende“.
nonisolated struct CueTrim: Equatable {
    /// Kürzeste getrimmte Länge, damit In und Out nie aufeinanderfallen.
    static let minimumLength: TimeInterval = 0.1

    var inPoint: TimeInterval = 0
    var outPoint: TimeInterval?
    /// Länge des Mediums, falls bekannt.
    var mediaLength: TimeInterval?

    /// Effektives Ende: Out-Punkt oder Medienende.
    var end: TimeInterval? { outPoint ?? mediaLength }

    /// Dauer = Out − In; `nil`, solange das Ende unbekannt ist.
    var duration: TimeInterval? { end.map { max($0 - inPoint, 0) } }

    var isTrimmed: Bool { inPoint > 0 || outPoint != nil }

    /// Setzt den In-Punkt: nicht negativ und mindestens `minimumLength` vor dem Ende.
    mutating func setIn(_ seconds: TimeInterval) {
        let upper = end.map { max($0 - Self.minimumLength, 0) } ?? .greatestFiniteMagnitude
        inPoint = seconds.clamped(to: 0...upper)
    }

    /// Setzt den Out-Punkt: mindestens `minimumLength` hinter dem In-Punkt, am Medienende wieder `nil`.
    mutating func setOut(_ seconds: TimeInterval) {
        let lower = inPoint + Self.minimumLength
        if let mediaLength, seconds >= mediaLength {
            outPoint = nil
        } else {
            outPoint = max(seconds, lower)
        }
    }

    /// Kürzt bzw. verlängert über die Dauer: Out = In + Dauer, höchstens bis Medienende.
    mutating func setDuration(_ seconds: TimeInterval) {
        setOut(inPoint + max(seconds, 0))
    }

    mutating func reset() {
        inPoint = 0
        outPoint = nil
    }
}

nonisolated extension Cue {
    func trim(mediaLength: TimeInterval?) -> CueTrim {
        CueTrim(inPoint: inPoint, outPoint: outPoint, mediaLength: mediaLength)
    }

    mutating func applyTrim(_ trim: CueTrim) {
        inPoint = trim.inPoint
        outPoint = trim.outPoint
    }
}
