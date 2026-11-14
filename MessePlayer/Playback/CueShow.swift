import Foundation

/// Aufgelöste Cue-Liste, bereit für die `CueEngine`: Adressen, Dauern und Gruppen ohne UI-Bezug.
struct CueShow: Equatable {
    var cues: [ShowCue] = []
    var groups: [ShowGroup] = []
    /// Standardausgang für Cues ohne eigene Wahl (der erste des Projekts).
    var primaryOutputID: OutputDefinition.ID?
    /// Logische Ausgänge des Projekts; je Ausgang gibt es ein Ausgabefenster.
    var outputs: [OutputDefinition] = []

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
    /// Nummer und Anzeigename (für Fernsteuerung und Meldungen).
    var number = ""
    var title = ""
    /// `nil` bei Audio; sonst der Ausgang, auf dem der Inhalt erscheint.
    var outputID: OutputDefinition.ID?
    var wait: TimeInterval = 0
    /// `nil`, solange die Medienlänge unbekannt ist.
    var duration: TimeInterval?
    /// Video oder Audio ohne Out-Punkt: Das Ende meldet der Player, die Dauer dient nur der Restzeit-Anzeige.
    var endsWithMedia = false
    var followAction = FollowAction.hold
    /// Nachwarten bei „Mit nächstem starten“, ab Start dieses Cues.
    var postWait: TimeInterval = 0
    /// Fade- oder Stopp-Cue.
    var action: CueAction?
    var schedule: CueSchedule?
    /// Überblendung beim Erscheinen, wenn der Cue nicht in einer Gruppe läuft.
    var blendIn: TimeInterval = 0
    /// Blende, wenn ein Video am Ende auf Schwarz geht.
    var blendOut: TimeInterval = 0
    var audio = AudioLevel()
    var scaling = ContentScaling.fit
    /// Getrimmter Bereich in Sekunden der Quelle (`outPoint == nil` = bis Medienende).
    var inPoint: TimeInterval = 0
    var outPoint: TimeInterval?

    var item: PlayableMedium? {
        if case .media(let item, _) = content { item } else { nil }
    }

    /// Bild oder Video mit sichtbarem Inhalt (Audio und Steuer-Cues belegen keinen Ausgang).
    var isVisual: Bool {
        guard let item else { return false }
        return item.medium.kind != .audio
    }

    var isVideo: Bool { item?.medium.kind == .video }

    var isAudio: Bool { item?.medium.kind == .audio }
}

struct ShowGroup: Equatable {
    let id: CueGroup.ID
    let range: ClosedRange<Int>
    var mode: CueGroup.Mode
    var crossfade: TimeInterval
    var isShuffled = false
}

extension ProjectDocument {
    /// Löst die Cue-Liste zum Abspielen auf. `mediaLength` liefert die Länge eines Videos/Audios, falls bekannt.
    func show(in packageURL: URL?, mediaLength: (URL) -> TimeInterval? = { _ in nil }) -> CueShow {
        let primary = project.outputs.first?.id
        let cues = project.cues.map { cue in
            showCue(cue, in: packageURL, primaryOutputID: primary, mediaLength: mediaLength)
        }
        let groups = project.groups.compactMap { group in
            project.cueRange(of: group).map { ShowGroup(id: group.id, range: $0, mode: group.mode, crossfade: group.crossfade, isShuffled: group.isShuffled) }
        }
        return CueShow(cues: cues, groups: groups, primaryOutputID: primary, outputs: project.outputs)
    }

    private func displayTitle(of cue: Cue) -> String {
        if !cue.name.isEmpty { return cue.name }
        if let action = cue.action { return project.title(of: action) }
        return cue.mediumID.flatMap(project.medium(withID:))?.displayName ?? String(localized: "Steuer-Cue")
    }

    private func showCue(_ cue: Cue, in packageURL: URL?, primaryOutputID: OutputDefinition.ID?, mediaLength: (URL) -> TimeInterval?) -> ShowCue {
        var show = ShowCue(id: cue.id, content: .control, wait: cue.wait, duration: 0, followAction: cue.followAction)
        show.postWait = cue.postWait
        show.number = cue.number
        show.title = displayTitle(of: cue)
        show.action = cue.action
        show.schedule = cue.schedule
        show.blendIn = cue.blendIn
        show.blendOut = cue.blendOut
        show.audio = cue.audioLevel
        show.scaling = cue.scaling
        show.inPoint = cue.inPoint
        show.outPoint = cue.outPoint
        guard let mediumID = cue.mediumID else {
            show.duration = cue.action?.duration ?? 0
            return show
        }
        guard let medium = project.medium(withID: mediumID), let item = playable(medium, in: packageURL) else {
            show.content = .missing
            return show
        }
        show.content = .media(item, layers: renderLayers(cue.layers, in: packageURL))
        show.outputID = medium.kind == .audio ? nil : cue.outputID ?? primaryOutputID
        show.duration = project.duration(of: cue, mediaLength: mediaLength(item.url))
        show.endsWithMedia = medium.kind != .image && cue.outPoint == nil
        return show
    }
}
