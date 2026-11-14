import Foundation

/// Zustand für die Fernsteuerung (JSON, Version `RemoteAPI.version`). Siehe `docs/REMOTE-API.md`.
/// Zeiten sind absolut, damit sich der Zustand nur bei Ereignissen ändert; die App rechnet die Restzeit selbst.
nonisolated struct RemoteState: Codable, Equatable {
    struct CueRef: Codable, Equatable {
        let id: UUID
        let number: String
        let title: String
    }

    struct RunningCue: Codable, Equatable {
        let cue: CueRef
        /// `waiting` (Warten läuft) oder `running`.
        let phase: String
        /// Beginn und Länge der aktuellen Phase; `pausedAt` bei Pause. Restzeit = duration − ((pausedAt ?? jetzt) − startedAt).
        let startedAt: Date?
        let duration: TimeInterval?
        let pausedAt: Date?
    }

    struct Output: Codable, Equatable {
        let id: UUID
        let name: String
        let isBlack: Bool
    }

    struct ScheduledStart: Codable, Equatable {
        let cue: CueRef
        let date: Date
    }

    var apiVersion = RemoteAPI.version
    var playhead: CueRef?
    var running: [RunningCue] = []
    var isPaused = false
    var isBlack = false
    var outputs: [Output] = []
    /// „Loop beenden“ ist möglich.
    var canEndLoop = false
    var isTradeShowMode = false
    var nextScheduledStart: ScheduledStart?
    /// Hinweis wie in der Transportleiste (Medium fehlt, Ziel läuft nicht).
    var notice: String?
}

/// Eine Zeile der Cue-Liste für `GET /cues`.
nonisolated struct RemoteCue: Codable, Equatable {
    let id: UUID
    let number: String
    let title: String
    /// `image`, `video`, `audio` oder `control`.
    let kind: String
    let groupID: UUID?
}

enum RemoteAPI {
    static let version = 1

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension RemoteState {
    /// Momentaufnahme von Engine und Zeitplan.
    init(engine: CueEngine, timetable: CueTimetable?, isTradeShowMode: Bool) {
        let show = engine.show
        func ref(_ id: Cue.ID) -> CueRef? {
            show.index(of: id).map { CueRef(id: id, number: show.cues[$0].number, title: show.cues[$0].title) }
        }
        playhead = engine.playheadID.flatMap(ref)
        running = show.cues.compactMap { cue in
            guard let runningCue = engine.running[cue.id], let cueRef = ref(cue.id) else { return nil }
            return RunningCue(
                cue: cueRef,
                phase: runningCue.phase == .waiting ? "waiting" : "running",
                startedAt: runningCue.progress?.startedAt,
                duration: runningCue.progress?.duration,
                pausedAt: runningCue.progress?.pausedAt
            )
        }
        isPaused = engine.isPaused
        isBlack = engine.isBlack
        outputs = show.outputs.map { Output(id: $0.id, name: $0.name, isBlack: engine.blackOutputIDs.contains($0.id)) }
        canEndLoop = !engine.loopTargets.isEmpty
        self.isTradeShowMode = isTradeShowMode
        nextScheduledStart = timetable?.nextStart.flatMap { start in ref(start.cueID).map { ScheduledStart(cue: $0, date: start.date) } }
        if let id = engine.missingCueID, let cue = ref(id) {
            notice = String(localized: "Cue \(cue.number): Medium fehlt")
        } else if let id = engine.inactiveTargetCueID, let cue = ref(id) {
            notice = String(localized: "Cue \(cue.number): Ziel läuft nicht, übersprungen")
        }
    }
}

extension RemoteCue {
    static func list(of show: CueShow) -> [RemoteCue] {
        show.cues.enumerated().map { index, cue in
            RemoteCue(id: cue.id, number: cue.number, title: cue.title, kind: cue.remoteKind, groupID: show.group(at: index)?.id)
        }
    }
}

private extension ShowCue {
    var remoteKind: String {
        if action != nil || item == nil { return "control" }
        return item?.medium.kind.rawValue ?? "control"
    }
}
