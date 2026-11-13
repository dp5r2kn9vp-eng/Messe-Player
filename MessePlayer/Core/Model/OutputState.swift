import Foundation

/// Was ein Ausgang zeigen soll.
/// `isBlack` liegt über jedem Inhalt, damit nach dem Aufheben der vorherige Inhalt unverändert weiterläuft.
struct OutputState: Equatable {
    var content: OutputContent = .idle
    var isBlack = false
    /// Alle laufenden Cues angehalten (P).
    var isPaused = false
    /// Überblendzeit für den nächsten Inhaltswechsel in Sekunden (0 = harter Schnitt).
    var transition: TimeInterval = 0
}

enum OutputContent: Equatable {
    /// Ruhebild (Logo): nichts gestartet oder nach „Stopp alle“.
    case idle
    /// Schwarz, z. B. nach dem Ende eines Videos mit „Halten“.
    case blank(step: Int)
    /// Inhalt eines Cues.
    case cue(CueFrame)

    /// Jeder Inhaltswechsel bekommt eine neue Identität, damit der Renderer überblendet.
    var transitionID: String {
        switch self {
        case .idle: "idle"
        case .blank(let step): "blank-\(step)"
        case .cue(let frame): "cue-\(frame.step)"
        }
    }

    var frame: CueFrame? {
        if case .cue(let frame) = self { frame } else { nil }
    }
}

/// Ein Medium samt abspielbarer Adresse – alles, was der Renderer braucht.
struct PlayableMedium: Equatable {
    let medium: Medium
    let url: URL
}

/// Ebene mit aufgelöster Bildadresse, bereit für den Renderer.
struct RenderLayer: Equatable, Identifiable {
    let layer: Layer
    /// Nur bei Bild-Ebenen; `nil`, wenn das Medium fehlt.
    let imageURL: URL?

    var id: Layer.ID { layer.id }
}

/// Sichtbarer Inhalt eines Cues. `step` zählt hoch, damit auch derselbe Cue zweimal hintereinander neu startet.
struct CueFrame: Equatable {
    let cueID: Cue.ID
    let item: PlayableMedium
    var layers: [RenderLayer] = []
    let step: Int
    var playback = PlaybackSettings()
}

/// Darstellung und Ton eines Cues im Renderer.
struct PlaybackSettings: Equatable {
    var scaling = ContentScaling.fit
    var audio = AudioLevel()
    /// Spielzeit für den Fade aus; `nil`, solange die Länge unbekannt ist.
    var playLength: TimeInterval?
    /// In-Punkt: Wiedergabe beginnt hier (Sekunden der Quelle).
    var startTime: TimeInterval = 0
    /// Out-Punkt; `nil` = bis Medienende.
    var endTime: TimeInterval?
}
