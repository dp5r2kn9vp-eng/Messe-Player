import Foundation
import Observation

/// Phase eines laufenden Cues. Beendete Cues stehen nicht mehr in `CueEngine.running`.
enum CuePhase: Equatable {
    case waiting
    case running
}

/// Ein gestarteter Cue: Bereit → Wartet → Läuft → Beendet (+ Pausiert über `CueEngine.isPaused`).
struct RunningCue: Equatable {
    let cueID: Cue.ID
    var phase = CuePhase.waiting
    /// Restzeit der aktuellen Phase; `nil`, solange die Länge eines Videos unbekannt ist.
    var progress: StepProgress?
    /// Durchlauf der Gruppe, in der der Cue läuft.
    var groupRun: GroupRun?
    /// Kennung des Starts, damit verspätete Meldungen des Renderers ignoriert werden.
    let step: Int
    var appearedAt: Date?
}

/// Durchlauf einer Gruppe: Reihenfolge, Zähler für „n-mal“ und Schutz vor Endlosschleifen ohne Inhalt.
struct GroupRun: Equatable {
    let groupID: CueGroup.ID
    var pass = 1
    var hasPlayed = false
    /// Cues dieses Durchlaufs in Abspielfolge (Listenfolge oder zufällig).
    var order: [Cue.ID] = []
    /// Stelle des laufenden Cues in `order`.
    var position = 0

    /// Folgender Cue im Durchlauf; `nil` am Ende des Durchlaufs.
    var nextCueID: Cue.ID? {
        order.indices.contains(position + 1) ? order[position + 1] : nil
    }
}

/// Cue-Engine: Abspielkopf, GO, Warten, Dauer, Folgeaktionen, Gruppen-Loop, Pause, Stopp, Black.
/// Ohne UI-Abhängigkeit; Zeit über `StepScheduler` und `now`, Ton über `AudioCueOutput`, damit Tests ohne Echtzeit laufen.
@Observable
final class CueEngine {
    /// Inhalt und Überblendung eines Ausgangs.
    private struct Channel: Equatable {
        var content = OutputContent.idle
        var transition: TimeInterval = 0
    }

    private(set) var show = CueShow()
    /// Cue, den das nächste GO startet; `nil` = Ende der Liste.
    private(set) var playheadID: Cue.ID?
    private(set) var running: [Cue.ID: RunningCue] = [:]
    /// Black alle (B): liegt über allen Ausgängen.
    private(set) var isBlack = false
    /// Black je Ausgang (⇧B bzw. Schaltfläche am Ausgang).
    private(set) var blackOutputIDs: Set<OutputDefinition.ID> = []
    private(set) var isPaused = false
    /// Zuletzt per GO gestarteter Cue ohne Medium (Fehlermeldung in der Transportleiste).
    private(set) var missingCueID: Cue.ID?
    /// Steuerfenster, dessen Cue-Liste geladen ist.
    private(set) var ownerID: UUID?
    private var channels: [OutputDefinition.ID: Channel] = [:]

    @ObservationIgnored private let scheduler: any StepScheduler
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let audio: any AudioCueOutput
    @ObservationIgnored private let shuffle: GroupOrder.Shuffle
    /// Hörbare Audio-Cues mit der Kennung ihres Starts.
    @ObservationIgnored private var audibleSteps: [Cue.ID: Int] = [:]
    @ObservationIgnored private var handles: [Cue.ID: Cancellation] = [:]
    @ObservationIgnored private var step = 0
    @ObservationIgnored private var pausedAt: Date?
    /// Verzögerte Starts durch Nachwarten, je auslösendem Cue (Restzeit + Zeitgeber).
    @ObservationIgnored private var pendingStarts: [Cue.ID: StepProgress] = [:]
    @ObservationIgnored private var pendingHandles: [Cue.ID: Cancellation] = [:]

    /// Kurzes Ausblenden der Audio-Cues bei „Stopp alle“; der Notfall-Stopp schneidet hart.
    static let audioStopFade: TimeInterval = 0.2

    init(
        scheduler: any StepScheduler = TaskStepScheduler(),
        now: @escaping () -> Date = Date.init,
        audio: any AudioCueOutput = AudioCuePlayers(),
        shuffle: @escaping GroupOrder.Shuffle = GroupOrder.random
    ) {
        self.scheduler = scheduler
        self.now = now
        self.audio = audio
        self.shuffle = shuffle
    }

    // MARK: Cue-Liste

    /// Lädt die Cue-Liste eines Steuerfensters neu: alles stoppt, der Abspielkopf steht auf dem ersten Cue.
    func load(_ show: CueShow, owner: UUID? = nil) {
        stopAll()
        self.show = show
        ownerID = owner
        playheadID = show.cues.first?.id
    }

    /// Übernimmt Änderungen der Liste, ohne laufende Cues zu unterbrechen.
    func update(_ newShow: CueShow) {
        let oldPlayheadIndex = playheadIndex
        show = newShow
        for id in running.keys where newShow.index(of: id) == nil {
            stopAudio(id, fadeOut: Self.audioStopFade)
            cancel(id)
        }
        for id in pendingStarts.keys where newShow.index(of: id) == nil {
            cancelPendingStart(id)
        }
        refreshVisibleFrames()
        refreshAudio()
        refreshUnknownDurations()
        if let playheadID, newShow.index(of: playheadID) == nil {
            self.playheadID = oldPlayheadIndex.flatMap { newShow.cues.indices.contains($0) ? newShow.cues[$0].id : nil }
        }
    }

    // MARK: Abspielkopf

    var playheadIndex: Int? {
        playheadID.flatMap(show.index(of:))
    }

    func setPlayhead(_ id: Cue.ID?) {
        playheadID = id.flatMap { show.index(of: $0) == nil ? nil : $0 }
    }

    /// Bewegt den Abspielkopf um `offset` Zeilen, ohne zu starten.
    func movePlayhead(by offset: Int) {
        guard !show.cues.isEmpty else { return }
        let current = playheadIndex ?? show.cues.count
        let target = min(max(current + offset, 0), show.cues.count - 1)
        playheadID = show.cues[target].id
    }

    // MARK: Transport

    /// Startet den Cue am Abspielkopf (in einer Gruppe deren Durchlauf von vorn) samt Kette „Mit nächstem starten“.
    func go() {
        guard let index = playheadIndex else { return }
        startChain(at: show.group(at: index)?.range.lowerBound ?? index, manual: true)
    }

    /// Startet einen Cue sofort (Doppelklick), unabhängig vom Abspielkopf; in einer Gruppe beginnt der Durchlauf mit ihm.
    func start(_ id: Cue.ID) {
        guard let index = show.index(of: id) else { return }
        startChain(at: index, manual: true, keepsFirstCue: true)
    }

    /// Hält alle laufenden Cues samt Restzeit an bzw. setzt sie fort. `false`, wenn nichts läuft.
    @discardableResult
    func togglePause() -> Bool {
        guard !running.isEmpty || hasPendingStarts else { return false }
        isPaused ? resume() : pause()
        return true
    }

    /// Beendet alle Cues und Loops; Audio blendet kurz aus, die Ausgänge zeigen das Ruhebild, der Abspielkopf bleibt.
    func stopAll() {
        stop(audioFade: Self.audioStopFade)
    }

    /// Notfall-Stopp (⌘.): wie „Stopp alle“, aber auch Audio endet sofort ohne Ausblenden.
    func emergencyStop() {
        stop(audioFade: 0)
    }

    private func stop(audioFade: TimeInterval) {
        for id in audibleSteps.keys {
            stopAudio(id, fadeOut: audioFade)
        }
        if isPaused { audio.setPaused(false) }
        handles.values.forEach { $0.cancel() }
        handles = [:]
        pendingHandles.values.forEach { $0.cancel() }
        pendingHandles = [:]
        pendingStarts = [:]
        running = [:]
        channels = [:]
        isPaused = false
        pausedAt = nil
        missingCueID = nil
    }

    /// Black wirkt sofort auf alle Ausgänge; die Cues laufen darunter weiter.
    func toggleBlack() {
        isBlack.toggle()
    }

    /// Black nur für einen Ausgang; andere Ausgänge und alle Cues laufen unverändert weiter.
    func toggleBlack(output id: OutputDefinition.ID) {
        if blackOutputIDs.remove(id) == nil {
            blackOutputIDs.insert(id)
        }
    }

    // MARK: Renderer

    /// Meldung des Renderers: Video zu Ende oder Medium defekt.
    func mediaDidFinish(cueID: Cue.ID, step finished: Int) {
        guard let cue = running[cueID], cue.step == finished, cue.phase == .running else { return }
        end(cueID)
    }

    // MARK: Abfragen

    /// Zustand des Ausgangs `outputID` (Inhalt + Black + Pause).
    func state(for outputID: OutputDefinition.ID?) -> OutputState {
        let channel = outputID.flatMap { channels[$0] } ?? Channel()
        let black = isBlack || outputID.map(blackOutputIDs.contains) == true
        return OutputState(content: channel.content, isBlack: black, isPaused: isPaused, transition: channel.transition)
    }

    /// Zustand des ersten Ausgangs (Standardausgang).
    var state: OutputState {
        state(for: show.primaryOutputID)
    }

    /// Medium, das voraussichtlich als Nächstes auf dem Ausgang erscheint (zum Vorladen).
    func upcoming(on outputID: OutputDefinition.ID?) -> PlayableMedium? {
        guard let frame = state(for: outputID).content.frame, let index = show.index(of: frame.cueID) else { return nil }
        let inGroup = running[frame.cueID]?.groupRun?.nextCueID.flatMap(show.index(of:))
        let next = inGroup ?? show.group(at: index).flatMap { $0.range.upperBound == index ? $0.range.lowerBound : nil } ?? index + 1
        return show.cues.indices.contains(next) ? show.cues[next].item : nil
    }

    /// Ausgang des Cues am Abspielkopf (Ziel von ⇧B); ohne Bildinhalt der erste Ausgang.
    var playheadOutputID: OutputDefinition.ID? {
        playheadIndex.flatMap { show.cues[$0].isVisual ? outputKey(of: show.cues[$0]) : nil } ?? show.primaryOutputID
    }

    /// Anzahl der Ausgänge, die gerade ein Video zeigen (Warnung bei zu vielen parallelen Videos).
    var parallelVideoCount: Int {
        channels.values.count { $0.content.frame?.item.medium.kind == .video }
    }

    /// Ein Folge-Cue wartet noch auf sein Nachwarten.
    var hasPendingStarts: Bool {
        !pendingStarts.isEmpty
    }

    func isShowing(_ mediumID: Medium.ID) -> Bool {
        channels.values.contains { $0.content.frame?.item.medium.id == mediumID }
    }

    /// Cues, deren Inhalt gerade auf einem Ausgang zu sehen ist.
    var visibleCueIDs: [Cue.ID] {
        show.cues.map(\.id).filter { id in channels.values.contains { $0.content.frame?.cueID == id } }
    }

    // MARK: Ablauf

    /// Startet den Cue an `index` und alle folgenden mit „Mit nächstem starten“; setzt danach den Abspielkopf.
    /// Eine Gruppe beginnt einen neuen Durchlauf; `keepsFirstCue` startet ihn mit dem Cue an `index`.
    private func startChain(at index: Int, manual: Bool, keepsFirstCue: Bool = false) {
        if manual {
            missingCueID = nil
            if isPaused { resume() }
        }
        var current = index
        while true {
            if let group = show.group(at: current) {
                let run = makeRun(group, first: keepsFirstCue ? show.cues[current].id : nil)
                launch(at: run.order.first.flatMap(show.index(of:)) ?? current, groupRun: run, manual: manual)
            } else {
                launch(at: current, groupRun: nil, manual: manual)
            }
            guard effectiveFollowAction(at: current) == .continueWithNext, show.cues.indices.contains(current + 1) else { break }
            let postWait = show.cues[current].postWait
            if postWait > 0 {
                schedulePendingStart(after: show.cues[current].id, delay: postWait)
                break
            }
            current += 1
        }
        advancePlayhead(from: index, to: current, manual: manual)
    }

    /// GO setzt den Kopf hinter die gestartete Kette bzw. Gruppe; automatische Starts nur, wenn er auf ihnen stand.
    private func advancePlayhead(from first: Int, to last: Int, manual: Bool) {
        let end = show.group(at: last)?.range.upperBound ?? last
        if !manual {
            guard let head = playheadIndex, (first...end).contains(head) else { return }
        }
        playheadID = show.cues.indices.contains(end + 1) ? show.cues[end + 1].id : nil
    }

    /// In Gruppen gilt immer „Weiter nach Ende“; was nach der Gruppe passiert, entscheidet `finish`.
    private func effectiveFollowAction(at index: Int) -> FollowAction {
        show.group(at: index) == nil ? show.cues[index].followAction : .followOnEnd
    }

    private func launch(at index: Int, groupRun: GroupRun?, manual: Bool) {
        let cue = show.cues[index]
        stopAudio(cue.id, fadeOut: Self.audioStopFade)
        cancel(cue.id)
        cancelPendingStart(cue.id)
        if case .missing = cue.content {
            if manual { missingCueID = cue.id }
            finish(at: index, groupRun: groupRun)
            return
        }
        step += 1
        running[cue.id] = RunningCue(cueID: cue.id, groupRun: groupRun, step: step)
        guard cue.wait > 0 else {
            appear(cue.id)
            return
        }
        running[cue.id]?.progress = StepProgress(startedAt: now(), duration: cue.wait)
        schedule(cue.id, after: cue.wait) { [weak self] in self?.appear(cue.id) }
    }

    /// Ende von „Warten“: Inhalt erscheint (ersetzt den Cue auf demselben Ausgang), dann läuft die Dauer.
    private func appear(_ id: Cue.ID) {
        guard var runningCue = running[id], let index = show.index(of: id) else { return }
        let cue = show.cues[index]
        runningCue.phase = .running
        runningCue.appearedAt = now()
        runningCue.progress = cue.duration.map { StepProgress(startedAt: now(), duration: $0) }
        if cue.endsWithMedia || (cue.duration ?? 0) > 0 {
            runningCue.groupRun?.hasPlayed = true
        }
        running[id] = runningCue
        display(cue, step: runningCue.step, groupRun: runningCue.groupRun)

        guard !cue.endsWithMedia else { return }
        let duration = cue.duration ?? 0
        if duration > 0 {
            schedule(id, after: duration) { [weak self] in self?.end(id) }
        } else {
            end(id)
        }
    }

    private func display(_ cue: ShowCue, step: Int, groupRun: GroupRun?) {
        if cue.isAudio {
            startAudio(cue, step: step)
            return
        }
        guard cue.isVisual, case .media(let item, let layers) = cue.content, let outputID = outputKey(of: cue) else { return }
        for other in running.values where other.cueID != cue.id && other.phase == .running {
            if let otherCue = show.index(of: other.cueID).map({ show.cues[$0] }), otherCue.isVisual, outputKey(of: otherCue) == outputID {
                cancel(other.cueID)
            }
        }
        let crossfade = groupRun.flatMap { run in show.groups.first { $0.id == run.groupID }?.crossfade } ?? cue.blendIn
        var frame = CueFrame(cueID: cue.id, item: item, layers: layers, step: step)
        frame.apply(cue)
        channels[outputID] = Channel(content: .cue(frame), transition: crossfade)
    }

    /// Ende der Dauer: Folgeaktion; ein Video geht auf Schwarz, wenn nicht sofort ein Folgecue erscheint.
    private func end(_ id: Cue.ID) {
        guard let runningCue = running[id], let index = show.index(of: id) else { return }
        stopAudio(id, fadeOut: 0)
        cancel(id)
        let cue = show.cues[index]
        finish(at: index, groupRun: runningCue.groupRun)
        if cue.isVideo, let outputID = outputKey(of: cue), channels[outputID]?.content.frame?.step == runningCue.step {
            step += 1
            channels[outputID] = Channel(content: .blank(step: step), transition: cue.blendOut)
        }
    }

    /// Folgeaktion nach dem Ende (oder Überspringen) des Cues an `index`.
    private func finish(at index: Int, groupRun: GroupRun?) {
        if let groupRun, let group = show.groups.first(where: { $0.id == groupRun.groupID }), group.range.contains(index) {
            finishInGroup(group, at: index, run: groupRun)
        } else if show.cues[index].followAction == .followOnEnd {
            startNext(after: index)
        }
    }

    /// Mitglieder laufen in der Folge des Durchlaufs weiter; am Ende Rücksprung (Loop/n-mal),
    /// danach „Danach“ des letzten Cues der Gruppe in der Liste.
    private func finishInGroup(_ group: ShowGroup, at index: Int, run: GroupRun) {
        if let (nextIndex, nextRun) = nextInRun(run, of: group) {
            launch(at: nextIndex, groupRun: nextRun, manual: false)
            return
        }
        if run.hasPlayed, repeats(group, after: run.pass) {
            let nextRun = makeRun(group, pass: run.pass + 1, previousLast: run.order.last)
            launch(at: nextRun.order.first.flatMap(show.index(of:)) ?? group.range.lowerBound, groupRun: nextRun, manual: false)
        } else if show.cues[group.range.upperBound].followAction != .hold {
            startNext(after: group.range.upperBound)
        }
    }

    /// Nächster noch vorhandener Cue des Durchlaufs (gelöschte Cues werden übersprungen).
    private func nextInRun(_ run: GroupRun, of group: ShowGroup) -> (Int, GroupRun)? {
        var next = run
        while let id = next.nextCueID {
            next.position += 1
            if let index = show.index(of: id), group.range.contains(index) { return (index, next) }
        }
        return nil
    }

    private func makeRun(_ group: ShowGroup, pass: Int = 1, first: Cue.ID? = nil, previousLast: Cue.ID? = nil) -> GroupRun {
        let ids = show.cues[group.range].map(\.id)
        let order = GroupOrder.pass(of: ids, isShuffled: group.isShuffled, first: first, previousLast: previousLast, shuffle: shuffle)
        return GroupRun(groupID: group.id, pass: pass, order: order)
    }

    private func repeats(_ group: ShowGroup, after pass: Int) -> Bool {
        switch group.mode {
        case .loop: true
        case .repeatCount(let count): pass < count
        }
    }

    /// „Weiter nach Ende“ beim letzten Cue der Liste wirkt wie Halten.
    private func startNext(after index: Int) {
        guard show.cues.indices.contains(index + 1) else { return }
        startChain(at: index + 1, manual: false)
    }

    // MARK: Nachwarten

    /// Der Folge-Cue von `id` startet nach `delay` (ab Start von `id`), auch wenn `id` vorher endet.
    private func schedulePendingStart(after id: Cue.ID, delay: TimeInterval) {
        pendingStarts[id] = StepProgress(startedAt: now(), duration: delay)
        schedulePending(id, after: delay)
    }

    private func schedulePending(_ id: Cue.ID, after seconds: TimeInterval) {
        pendingHandles[id]?.cancel()
        pendingHandles[id] = scheduler.schedule(after: .seconds(seconds)) { [weak self] in self?.firePendingStart(id) }
    }

    private func firePendingStart(_ id: Cue.ID) {
        cancelPendingStart(id)
        guard let index = show.index(of: id) else { return }
        startNext(after: index)
    }

    private func cancelPendingStart(_ id: Cue.ID) {
        pendingHandles.removeValue(forKey: id)?.cancel()
        pendingStarts[id] = nil
    }

    // MARK: Pause

    private func pause() {
        let time = now()
        isPaused = true
        pausedAt = time
        audio.setPaused(true)
        handles.values.forEach { $0.cancel() }
        handles = [:]
        pendingHandles.values.forEach { $0.cancel() }
        pendingHandles = [:]
        for id in running.keys {
            running[id]?.progress?.pausedAt = time
        }
        for id in pendingStarts.keys {
            pendingStarts[id]?.pausedAt = time
        }
    }

    private func resume() {
        let time = now()
        let pausedFor = pausedAt.map { time.timeIntervalSince($0) } ?? 0
        isPaused = false
        pausedAt = nil
        audio.setPaused(false)
        for (id, runningCue) in running {
            var resumed = runningCue
            resumed.progress = runningCue.progress?.resumed(at: time)
            resumed.appearedAt = runningCue.appearedAt.map { $0 + pausedFor }
            running[id] = resumed
            reschedule(resumed)
        }
        for (id, progress) in pendingStarts {
            let resumed = progress.resumed(at: time)
            pendingStarts[id] = resumed
            schedulePending(id, after: resumed.remaining(at: time))
        }
    }

    private func reschedule(_ runningCue: RunningCue) {
        let id = runningCue.cueID
        let remaining = runningCue.progress?.remaining(at: now()) ?? 0
        switch runningCue.phase {
        case .waiting:
            schedule(id, after: remaining) { [weak self] in self?.appear(id) }
        case .running:
            guard let cue = show.index(of: id).map({ show.cues[$0] }), !cue.endsWithMedia else { return }
            schedule(id, after: remaining) { [weak self] in self?.end(id) }
        }
    }

    // MARK: Hilfen

    private func schedule(_ id: Cue.ID, after seconds: TimeInterval, _ action: @escaping () -> Void) {
        handles[id]?.cancel()
        handles[id] = scheduler.schedule(after: .seconds(seconds), action)
    }

    private func startAudio(_ cue: ShowCue, step: Int) {
        guard let item = cue.item else { return }
        audibleSteps[cue.id] = step
        let playback = AudioCuePlayback(cueID: cue.id, item: item, step: step, playback: cue.playbackSettings)
        audio.play(playback) { [weak self] in
            self?.mediaDidFinish(cueID: cue.id, step: step)
        }
    }

    private func stopAudio(_ id: Cue.ID, fadeOut: TimeInterval) {
        guard audibleSteps.removeValue(forKey: id) != nil else { return }
        audio.stop(id, fadeOut: fadeOut)
    }

    /// Entfernt einen Cue ohne Folgeaktion (ersetzt, gelöscht oder neu gestartet).
    private func cancel(_ id: Cue.ID) {
        handles.removeValue(forKey: id)?.cancel()
        running[id] = nil
    }

    private func outputKey(of cue: ShowCue) -> OutputDefinition.ID? {
        cue.outputID ?? show.primaryOutputID
    }

    /// Geänderte Ebenen sichtbarer Cues sofort zeigen, ohne neu zu überblenden.
    private func refreshVisibleFrames() {
        for (outputID, channel) in channels {
            guard case .cue(var frame) = channel.content,
                  let cue = show.index(of: frame.cueID).map({ show.cues[$0] }),
                  case .media(let item, let layers) = cue.content, item == frame.item
            else { continue }
            frame.layers = layers
            frame.apply(cue)
            channels[outputID]?.content = .cue(frame)
        }
    }

    /// Lautstärke, Fades und nachträglich bekannte Länge an laufende Audio-Cues weitergeben.
    private func refreshAudio() {
        for id in audibleSteps.keys {
            guard let cue = show.index(of: id).map({ show.cues[$0] }) else { continue }
            audio.update(id, playback: cue.playbackSettings)
        }
    }

    /// Restzeit für Videos nachtragen, deren Länge erst jetzt bekannt ist.
    private func refreshUnknownDurations() {
        for (id, runningCue) in running where runningCue.phase == .running && runningCue.progress == nil {
            guard let appearedAt = runningCue.appearedAt,
                  let duration = show.index(of: id).flatMap({ show.cues[$0].duration })
            else { continue }
            running[id]?.progress = StepProgress(startedAt: appearedAt, duration: duration, pausedAt: pausedAt)
        }
    }
}

private extension ShowCue {
    var playbackSettings: PlaybackSettings {
        PlaybackSettings(scaling: scaling, audio: audio, playLength: duration, startTime: inPoint, endTime: outPoint)
    }
}

private extension CueFrame {
    /// Übernimmt Darstellung und Lautstärke aus der Liste (auch während der Cue läuft).
    mutating func apply(_ cue: ShowCue) {
        playback = cue.playbackSettings
    }
}
