import Foundation

/// Aufgelöste Cue-Liste, bereit für die `CueEngine`: Adressen, Dauern und Gruppen ohne UI-Bezug.
struct CueShow: Equatable {
    var cues: [ShowCue] = []
    var groups: [ShowGroup] = []
    /// Ausgang, den das Ausgabefenster zeigt (vorerst genau einer).
    var primaryOutputID: OutputDefinition.ID?

    func index(of id: Cue.ID) -> Int? {
        cues.firstIndex { $0.id == id }
    }

    func group(at index: Int) -> ShowGroup? {
        groups.first { $0.range.contains(index) }
    }
}

struct ShowCue: Equatable {
    enum Content: Equatable {
        /// Bild/Video (mit Ausgang) oder Audio (ohne Ausgang).
        case media(PlayableMedium, layers: [RenderLayer])
        /// Medium fehlt im Paket.
        case missing
        /// Steuer-Cue ohne Medium.
        case control
    }

    let id: Cue.ID
    var content: Content
    /// `nil` bei Audio; sonst der Ausgang, auf dem der Inhalt erscheint.
    var outputID: OutputDefinition.ID?
    var wait: TimeInterval = 0
    /// `nil`, solange die Medienlänge unbekannt ist.
    var duration: TimeInterval?
    /// Video ohne Out-Punkt: Das Ende meldet der Renderer, die Dauer dient nur der Restzeit-Anzeige.
    var endsWithMedia = false
    var followAction = FollowAction.hold
    /// Überblendung beim Erscheinen, wenn der Cue nicht in einer Gruppe läuft.
    var fadeIn: TimeInterval = 0

    var item: PlayableMedium? {
        if case .media(let item, _) = content { item } else { nil }
    }

    /// Bild oder Video mit sichtbarem Inhalt (Audio und Steuer-Cues belegen keinen Ausgang).
    var isVisual: Bool {
        guard let item else { return false }
        return item.medium.kind != .audio
    }

    var isVideo: Bool { item?.medium.kind == .video }
}

struct ShowGroup: Equatable {
    let id: CueGroup.ID
    let range: ClosedRange<Int>
    var mode: CueGroup.Mode
    var crossfade: TimeInterval
}

extension ProjectDocument {
    /// Löst die Cue-Liste zum Abspielen auf. `mediaLength` liefert die Länge eines Videos/Audios, falls bekannt.
    func show(in packageURL: URL?, mediaLength: (URL) -> TimeInterval? = { _ in nil }) -> CueShow {
        let primary = project.outputs.first?.id
        let cues = project.cues.map { cue in
            showCue(cue, in: packageURL, primaryOutputID: primary, mediaLength: mediaLength)
        }
        let groups = project.groups.compactMap { group in
            project.cueRange(of: group).map { ShowGroup(id: group.id, range: $0, mode: group.mode, crossfade: group.crossfade) }
        }
        return CueShow(cues: cues, groups: groups, primaryOutputID: primary)
    }

    private func showCue(_ cue: Cue, in packageURL: URL?, primaryOutputID: OutputDefinition.ID?, mediaLength: (URL) -> TimeInterval?) -> ShowCue {
        var show = ShowCue(id: cue.id, content: .control, wait: cue.wait, duration: 0, followAction: cue.followAction, fadeIn: cue.fadeIn)
        guard let mediumID = cue.mediumID else { return show }
        guard let medium = project.medium(withID: mediumID), let item = playable(medium, in: packageURL) else {
            show.content = .missing
            return show
        }
        show.content = .media(item, layers: renderLayers(cue.layers, in: packageURL))
        show.outputID = medium.kind == .audio ? nil : cue.outputID ?? primaryOutputID
        show.duration = project.duration(of: cue, mediaLength: mediaLength(item.url))
        show.endsWithMedia = medium.kind == .video && cue.outPoint == nil
        return show
    }
}
