import Foundation
import Observation

/// Geplanter Start eines Cues.
struct ScheduledStart: Equatable {
    let cueID: Cue.ID
    let date: Date
}

/// Startet Cues zur geplanten Uhrzeit wie GO auf diesen Cue.
/// Prüft regelmäßig die Wanduhr (robust gegen Ruhezustand und Uhrzeitwechsel); verpasste Zeiten werden nicht nachgeholt.
@Observable
final class CueTimetable {
    /// Abstand der Prüfungen, damit geänderte Zeiten und Uhrsprünge schnell erkannt werden.
    static let tick: TimeInterval = 5
    /// Wie spät ein Start noch ausgeführt wird (z. B. nach kurzem Ruhezustand).
    static let tolerance: TimeInterval = 60

    /// Nächster geplanter Start der geladenen Cue-Liste.
    private(set) var nextStart: ScheduledStart?
    /// Zuletzt wegen Pause ausgelassener Start (Hinweis in der Transportleiste).
    private(set) var skippedCueID: Cue.ID?

    @ObservationIgnored private let engine: CueEngine
    @ObservationIgnored private let scheduler: any StepScheduler
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let isEnabled: () -> Bool
    @ObservationIgnored private var lastCheck: Date?
    @ObservationIgnored private var handle: Cancellation?

    init(
        engine: CueEngine,
        scheduler: any StepScheduler = TaskStepScheduler(),
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        isEnabled: @escaping () -> Bool = TransportSettings.isScheduleEnabled
    ) {
        self.engine = engine
        self.scheduler = scheduler
        self.now = now
        self.calendar = calendar
        self.isEnabled = isEnabled
    }

    /// Beginnt zu prüfen; Zeiten vor dem Start zählen nicht.
    func start() {
        lastCheck = now()
        check()
    }

    func stop() {
        handle?.cancel()
        handle = nil
        lastCheck = nil
    }

    private func check() {
        let time = now()
        if let lastCheck, isEnabled() {
            for start in dueStarts(after: lastCheck, through: time) {
                fire(start)
            }
        }
        lastCheck = time
        nextStart = upcoming(after: time)
        let untilNext = nextStart.map { $0.date.timeIntervalSince(time) } ?? Self.tick
        handle = scheduler.schedule(after: .seconds(max(min(untilNext, Self.tick), 0.05))) { [weak self] in
            self?.check()
        }
    }

    private func fire(_ start: ScheduledStart) {
        guard engine.show.index(of: start.cueID) != nil else { return }
        if engine.isPaused {
            skippedCueID = start.cueID
            return
        }
        skippedCueID = nil
        engine.start(start.cueID)
    }

    /// Fällige Starts seit der letzten Prüfung, ohne zu weit zurückliegende (verpasst).
    private func dueStarts(after start: Date, through end: Date) -> [ScheduledStart] {
        scheduledCues.flatMap { cueID, schedule in
            schedule.occurrences(after: start, through: end, calendar: calendar)
                .filter { end.timeIntervalSince($0) <= Self.tolerance }
                .map { ScheduledStart(cueID: cueID, date: $0) }
        }
        .sorted { $0.date < $1.date }
    }

    private func upcoming(after date: Date) -> ScheduledStart? {
        scheduledCues.compactMap { cueID, schedule in
            schedule.nextOccurrence(after: date, calendar: calendar).map { ScheduledStart(cueID: cueID, date: $0) }
        }
        .min { $0.date < $1.date }
    }

    private var scheduledCues: [(Cue.ID, CueSchedule)] {
        engine.show.cues.compactMap { cue in cue.schedule.map { (cue.id, $0) } }
    }
}
