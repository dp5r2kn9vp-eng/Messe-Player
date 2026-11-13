import Foundation

/// Animation einer Ebene: wie sie erscheint, ob sie danach dauerhaft wirkt und ob sie wieder verschwindet.
/// Der Verlauf ist eine reine Funktion der Zeit seit Beginn des Eintrags – dadurch testbar und
/// auf Ausgang und Editor-Vorschau identisch.
nonisolated struct LayerAnimation: Codable, Equatable {
    enum Entrance: String, Codable, CaseIterable {
        case none, fade, slideUp, slideDown, slideLeft, slideRight, zoom, typewriter
    }

    enum Effect: String, Codable, CaseIterable {
        case none, blink, pulse
    }

    /// Momentaufnahme für den Renderer. `offset` ist relativ zur Bildfläche, `reveal` der sichtbare Textanteil.
    struct Frame: Equatable {
        var opacity = 1.0
        var offsetX = 0.0
        var offsetY = 0.0
        var scale = 1.0
        var reveal = 1.0
    }

    static let delayRange: ClosedRange<TimeInterval> = 0...30
    static let durationRange: ClosedRange<TimeInterval> = 0.1...5
    static let periodRange: ClosedRange<TimeInterval> = 0.3...5
    static let visibleRange: ClosedRange<TimeInterval> = 0.5...600

    /// Weg beim Hereingleiten, relativ zur Bildfläche.
    private static let slideDistance = 0.1
    private static let fadeOutDuration = 0.5

    var entrance = Entrance.none
    var delay: TimeInterval = 0
    var duration: TimeInterval = 0.8
    var effect = Effect.none
    var effectPeriod: TimeInterval = 1
    /// Blendet nach dieser Zeit (ab Erscheinen) wieder aus; `nil` = bleibt stehen.
    var visibleFor: TimeInterval?

    var isStatic: Bool {
        entrance == .none && delay == 0 && effect == .none && visibleFor == nil
    }

    /// Ab diesem Zeitpunkt bewegt sich nichts mehr; `nil`, wenn ein Dauereffekt läuft.
    /// Danach darf der Renderer anhalten, statt weiter jedes Bild neu zu zeichnen.
    var settlesAfter: TimeInterval? {
        guard effect == .none else { return nil }
        let entranceEnd = delay + (entrance == .none ? 0 : duration)
        guard let visibleFor else { return entranceEnd }
        return max(entranceEnd, delay + visibleFor + Self.fadeOutDuration)
    }

    /// Gemeinsamer Ruhezeitpunkt mehrerer Ebenen; `nil`, sobald eine dauerhaft animiert ist.
    static func settlesAfter(_ animations: [LayerAnimation]) -> TimeInterval? {
        animations.reduce(0) { latest, animation in
            guard let latest, let end = animation.settlesAfter else { return nil }
            return max(latest, end)
        }
    }

    func frame(at time: TimeInterval) -> Frame {
        guard time >= delay else { return Frame(opacity: 0, reveal: 0) }
        let local = time - delay
        var frame = entranceFrame(progress: entrance == .none ? 1 : min(local / max(duration, 0.01), 1))
        let entranceEnd = entrance == .none ? 0 : duration
        if local > entranceEnd {
            applyEffect(to: &frame, time: local - entranceEnd)
        }
        if let visibleFor, local > visibleFor {
            frame.opacity *= max(0, 1 - (local - visibleFor) / Self.fadeOutDuration)
        }
        return frame
    }

    private func entranceFrame(progress: Double) -> Frame {
        let eased = 1 - pow(1 - progress, 3)
        let remaining = (1 - eased) * Self.slideDistance
        switch entrance {
        case .none: return Frame()
        case .fade: return Frame(opacity: eased)
        case .slideUp: return Frame(opacity: eased, offsetY: remaining)
        case .slideDown: return Frame(opacity: eased, offsetY: -remaining)
        case .slideLeft: return Frame(opacity: eased, offsetX: remaining)
        case .slideRight: return Frame(opacity: eased, offsetX: -remaining)
        case .zoom: return Frame(opacity: eased, scale: 0.6 + 0.4 * eased)
        case .typewriter: return Frame(reveal: progress)
        }
    }

    private func applyEffect(to frame: inout Frame, time: TimeInterval) {
        let phase = (time / max(effectPeriod, 0.01)) * 2 * .pi
        switch effect {
        case .none: break
        case .blink: frame.opacity *= 0.575 + 0.425 * cos(phase)
        case .pulse: frame.scale *= 1 + 0.06 * sin(phase)
        }
    }
}
