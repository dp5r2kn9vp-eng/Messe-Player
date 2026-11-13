import Foundation

/// Was der Ausgang zeigen soll.
/// `isBlack` liegt über jedem Inhalt, damit nach dem Aufheben der vorherige Inhalt unverändert weiterläuft.
struct OutputState: Equatable {
    var content: OutputContent = .idle
    var isBlack = false
    /// Überblendzeit für den nächsten Inhaltswechsel in Sekunden (0 = harter Schnitt).
    var transition: TimeInterval = 0
}

enum OutputContent: Equatable {
    case idle
    /// Ein Medium dauerhaft; Videos laufen in Endlosschleife.
    case single(PlayableMedium)
    /// Aktueller Schritt eines laufenden Loops.
    case loop(LoopFrame)

    /// Jeder Inhaltswechsel bekommt eine neue Identität, damit der Renderer überblendet.
    var transitionID: String {
        switch self {
        case .idle: "idle"
        case .single(let item): "single-\(item.medium.id)"
        case .loop(let frame): frame.isGap ? "gap-\(frame.step)" : "step-\(frame.step)"
        }
    }
}

/// Ein Medium samt abspielbarer Adresse – alles, was der Renderer braucht.
struct PlayableMedium: Equatable {
    let medium: Medium
    let url: URL
}

/// Aufgelöste Gruppe, bereit zum Abspielen.
struct LoopPlaylist: Equatable {
    let groupID: MediaGroup.ID
    let crossfade: TimeInterval
    let items: [LoopItem]
}

struct LoopItem: Equatable {
    let entryID: Entry.ID
    let item: PlayableMedium
    let imageDuration: TimeInterval
}

/// Ein Schritt im Loop. `step` zählt hoch, damit auch derselbe Eintrag zweimal hintereinander neu startet.
struct LoopFrame: Equatable {
    let groupID: MediaGroup.ID
    let entryID: Entry.ID
    let item: PlayableMedium
    let step: Int
    /// Schwarze Pause nach einem Video.
    var isGap = false
}
