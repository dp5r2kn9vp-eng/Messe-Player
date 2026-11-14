import Foundation

/// Spur im Zeitstrahl: ein logischer Ausgang oder die Tonspur.
enum TimelineLane: Hashable {
    case output(OutputDefinition.ID)
    case audio
}

/// Simulierter Ablauf eines Cues (Sekunden ab dem ersten GO).
struct TimelineBar: Equatable, Identifiable {
    let cueID: Cue.ID
    let lane: TimelineLane
    /// T0: Beginn von „Warten“.
    let start: TimeInterval
    /// Ende von „Warten“ (Inhalt erscheint); `nil`, wenn der Cue vorher ersetzt wurde.
    var appear: TimeInterval?
    /// Ende der Dauer bzw. Abbruch durch Ersetzen; `nil` = läuft offen (Länge unbekannt oder Show-Ende).
    var end: TimeInterval?
    /// Nur Bild/Video: bis wann der Inhalt sichtbar bleibt; `nil` = bleibt stehen.
    var visibleUntil: TimeInterval?
    /// „Halten“: der nächste Cue startet erst per GO (→).
    var holds = false

    var id: String { "\(cueID)-\(start)" }
}

/// Wiederholungen einer Gruppe ab dem zweiten Durchlauf (⟲); einzelne Durchläufe werden nicht aufgefächert.
struct TimelineLoop: Equatable, Identifiable {
    let groupID: CueGroup.ID
    let lane: TimelineLane
    let start: TimeInterval
    /// `nil` = Loop läuft bis Stopp (offen).
    var end: TimeInterval?
    let mode: CueGroup.Mode
    var isShuffled = false
    /// Nach dem letzten Durchlauf einer n-mal-Gruppe wartet die Show auf GO (→).
    var holds = false

    var id: String { "\(groupID)-\(start)" }
}

/// Ergebnis der Simulation: Balken, Gruppen-Wiederholungen und Zeitpunkte, an denen ein GO nötig war.
struct ShowTimeline: Equatable {
    var bars: [TimelineBar] = []
    var loops: [TimelineLoop] = []
    var goTimes: [TimeInterval] = []

    /// Letzter bekannter Zeitpunkt (ohne offene Enden).
    var lastEvent: TimeInterval {
        let barTimes = bars.flatMap { [$0.start, $0.appear, $0.end, $0.visibleUntil].compactMap(\.self) }
        let loopTimes = loops.flatMap { [$0.start, $0.end].compactMap(\.self) }
        return (barTimes + loopTimes + goTimes).max() ?? 0
    }

    func bar(for cueID: Cue.ID) -> TimelineBar? {
        bars.first { $0.cueID == cueID }
    }
}

/// Simuliert die Cue-Liste ohne Ausgabe: Die echte `CueEngine` läuft mit virtueller Uhr, Ton und Videoende werden nachgebildet.
/// Zufallsgruppen erscheinen im ersten Durchlauf in Listenfolge, der ⟲-Abschnitt trägt den Hinweis „Zufall“.
/// Ab dem Abspielkopf „Erster Cue“ wird jedes nötige GO sofort gedrückt, sobald nichts mehr von selbst weiterläuft.
/// Gruppen erscheinen mit einem Durchlauf, weitere Durchläufe als ⟲-Abschnitt.
@MainActor
struct ShowSimulation {
    /// Schutz vor Endlosläufen (z. B. sehr viele Wiederholungen kurzer Cues).
    static let stepLimit = 20_000

    private let show: CueShow
    private let clock: VirtualClock
    private let engine: CueEngine
    private let origin: Date

    static func run(_ show: CueShow) -> ShowTimeline {
        ShowSimulation(show: show).run()
    }

    private init(show: CueShow) {
        let clock = VirtualClock()
        self.show = show
        self.clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: SimulatedAudioOutput(clock: clock), shuffle: { $0 })
        origin = clock.now
    }

    private func run() -> ShowTimeline {
        var recorder = Recorder(show: show)
        engine.load(show)
        var steps = 0
        while steps < Self.stepLimit {
            steps += 1
            if isSettled(recorder) {
                guard engine.playheadID != nil else { break }
                recorder.goTimes.append(time)
                engine.go()
            } else if !clock.runNext() {
                break
            }
            reportVideoEnds(&recorder)
            recorder.record(engine, at: time)
        }
        return recorder.timeline
    }

    private var time: TimeInterval {
        clock.now.timeIntervalSince(origin)
    }

    /// Nichts läuft mehr von selbst weiter: nur noch endlose Loops oder Cues mit unbekannter Länge.
    private func isSettled(_ recorder: Recorder) -> Bool {
        engine.running.values.allSatisfy { running in
            if let run = running.groupRun, recorder.isEndless(run) { return true }
            let cue = show.index(of: running.cueID).map { show.cues[$0] }
            return running.phase == .running && cue?.duration == nil
        }
    }

    /// Der Renderer meldet das Ende eines Videos; in der Simulation nach der bekannten Dauer.
    private func reportVideoEnds(_ recorder: inout Recorder) {
        for running in engine.running.values where running.phase == .running {
            guard recorder.videoEndsScheduled.insert(running.step).inserted,
                  let cue = show.index(of: running.cueID).map({ show.cues[$0] }),
                  cue.isVideo, cue.endsWithMedia, let duration = cue.duration
            else { continue }
            let engine = engine
            _ = clock.schedule(after: .seconds(duration)) {
                engine.mediaDidFinish(cueID: running.cueID, step: running.step)
            }
        }
    }
}

/// Schreibt aus den Zuständen der Engine Balken und Loop-Abschnitte mit.
@MainActor
private struct Recorder {
    let show: CueShow
    var bars: [TimelineBar] = []
    var loops: [TimelineLoop] = []
    var goTimes: [TimeInterval] = []
    var videoEndsScheduled: Set<Int> = []
    /// Offener Balken je Start-Kennung der Engine.
    private var barIndexByStep: [Int: Int] = [:]
    /// Start-Kennung je Balken, um ihn auf dem Ausgang wiederzuerkennen.
    private var stepByBar: [Int: Int] = [:]
    private var openLoopByGroup: [CueGroup.ID: Int] = [:]

    init(show: CueShow) {
        self.show = show
    }

    var timeline: ShowTimeline {
        ShowTimeline(bars: bars, loops: loops, goTimes: goTimes)
    }

    func isEndless(_ run: GroupRun) -> Bool {
        run.pass > 1 && show.groups.first { $0.id == run.groupID }?.mode == .loop
    }

    mutating func record(_ engine: CueEngine, at time: TimeInterval) {
        for running in engine.running.values {
            if let run = running.groupRun, run.pass > 1 {
                openLoopIfNeeded(run, at: time)
            } else {
                trackBar(running, at: time)
            }
        }
        closeEndedBars(engine, at: time)
        closeEndedLoops(engine, at: time)
        trackVisibility(engine, at: time)
    }

    private mutating func trackBar(_ running: RunningCue, at time: TimeInterval) {
        guard let cueIndex = show.index(of: running.cueID) else { return }
        let cue = show.cues[cueIndex]
        let barIndex: Int
        if let existing = barIndexByStep[running.step] {
            barIndex = existing
        } else {
            guard let lane = lane(of: cue) else { return }
            bars.append(TimelineBar(cueID: cue.id, lane: lane, start: time, holds: holds(at: cueIndex)))
            barIndex = bars.count - 1
            barIndexByStep[running.step] = barIndex
            stepByBar[barIndex] = running.step
        }
        if running.phase == .running, bars[barIndex].appear == nil {
            bars[barIndex].appear = time
        }
    }

    private mutating func closeEndedBars(_ engine: CueEngine, at time: TimeInterval) {
        let runningSteps = Set(engine.running.values.map(\.step))
        for (step, index) in barIndexByStep where !runningSteps.contains(step) {
            bars[index].end = time
            if bars[index].lane == .audio || bars[index].appear == nil {
                bars[index].visibleUntil = time
            }
            barIndexByStep[step] = nil
        }
    }

    /// Bild/Video bleiben über das Dauerende hinaus sichtbar, bis der Ausgang etwas anderes zeigt.
    private mutating func trackVisibility(_ engine: CueEngine, at time: TimeInterval) {
        for index in bars.indices where bars[index].visibleUntil == nil && bars[index].appear != nil {
            guard case .output(let outputID) = bars[index].lane else { continue }
            if engine.state(for: outputID).content.frame?.step != stepByBar[index] {
                bars[index].visibleUntil = time
            }
        }
    }

    private mutating func openLoopIfNeeded(_ run: GroupRun, at time: TimeInterval) {
        guard openLoopByGroup[run.groupID] == nil, let group = show.groups.first(where: { $0.id == run.groupID }) else { return }
        guard let lane = show.cues[group.range].lazy.compactMap(lane(of:)).first else { return }
        let holds = group.mode != .loop && show.cues[group.range.upperBound].followAction == .hold
        loops.append(TimelineLoop(groupID: group.id, lane: lane, start: time, mode: group.mode, isShuffled: group.isShuffled, holds: holds))
        openLoopByGroup[run.groupID] = loops.count - 1
    }

    private mutating func closeEndedLoops(_ engine: CueEngine, at time: TimeInterval) {
        for (groupID, index) in openLoopByGroup where !engine.running.values.contains(where: { $0.groupRun?.groupID == groupID }) {
            loops[index].end = time
            openLoopByGroup[groupID] = nil
        }
    }

    private func lane(of cue: ShowCue) -> TimelineLane? {
        if cue.isAudio { return .audio }
        guard cue.isVisual else { return nil }
        return (cue.outputID ?? show.primaryOutputID).map(TimelineLane.output)
    }

    /// Außerhalb von Gruppen zählt „Danach“ des Cues; in Gruppen nur beim letzten Mitglied einer Gruppe ohne Wiederholung
    /// (sonst trägt der ⟲-Abschnitt das Halten).
    private func holds(at index: Int) -> Bool {
        guard show.cues[index].followAction == .hold else { return false }
        guard let group = show.group(at: index) else { return true }
        return index == group.range.upperBound && group.mode == .repeatCount(1)
    }
}

/// Ton ohne Wiedergabe: Ein Audio-Cue meldet sein Ende nach der bekannten Dauer auf der virtuellen Uhr.
private final class SimulatedAudioOutput: AudioCueOutput {
    private let clock: VirtualClock
    private var finishes: [Cue.ID: Cancellation] = [:]

    init(clock: VirtualClock) {
        self.clock = clock
    }

    func play(_ playback: AudioCuePlayback, onFinish: @escaping () -> Void) {
        stop(playback.cueID, fadeOut: 0)
        guard let length = playback.playback.playLength else { return }
        finishes[playback.cueID] = clock.schedule(after: .seconds(length), onFinish)
    }

    func update(_ cueID: Cue.ID, playback: PlaybackSettings) {}

    func stop(_ cueID: Cue.ID, fadeOut: TimeInterval) {
        finishes.removeValue(forKey: cueID)?.cancel()
    }

    func setPaused(_ paused: Bool) {}
}
