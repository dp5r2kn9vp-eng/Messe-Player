import Foundation
import Testing
@testable import MessePlayer

/// Kalender und Zeitpunkte in fester Zeitzone, damit die Tests überall gleich laufen.
enum TimetableFixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Montag, 16.11.2026, hh:mm:ss.
    static func monday(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: hour, minute: minute, second: second)) ?? .now
    }
}

struct CueScheduleTests {
    let calendar = TimetableFixture.calendar

    @Test func dailyOccurrenceInRange() {
        let schedule = CueSchedule(minuteOfDay: 14 * 60)
        let dates = schedule.occurrences(after: TimetableFixture.monday(13, 0), through: TimetableFixture.monday(15, 0), calendar: calendar)
        #expect(dates == [TimetableFixture.monday(14, 0)])
    }

    @Test func weekdaysAreRespected() throws {
        // 3 = Dienstag
        let schedule = CueSchedule(minuteOfDay: 9 * 60 + 30, weekdays: [3])
        let next = try #require(schedule.nextOccurrence(after: TimetableFixture.monday(10, 0), calendar: calendar))
        #expect(next == TimetableFixture.monday(9, 30).addingTimeInterval(24 * 3600))
    }

    @Test func minuteIsClamped() {
        #expect(CueSchedule(minuteOfDay: 5000).minuteOfDay == 1439)
    }
}

@MainActor
struct CueTimetableTests {
    let clock = VirtualClock(now: TimetableFixture.monday(13, 59))
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: RecordingAudioOutput())
    }

    private func timetable(enabled: Bool = true) -> CueTimetable {
        let clock = clock
        return CueTimetable(engine: engine, scheduler: clock, now: { clock.now }, calendar: TimetableFixture.calendar) { enabled }
    }

    /// Standloop auf Ausgang 1, Präsentation um 14:00 auf demselben Ausgang.
    private func loadShow() -> (loop: [ShowCue], presentation: ShowCue) {
        let loop = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        var presentation = ShowFixture.cue(.video, duration: 600)
        presentation.schedule = CueSchedule(minuteOfDay: 14 * 60)
        engine.load(ShowFixture.show(loop + [presentation], groups: [(0...1, .loop)]))
        return (loop, presentation)
    }

    @Test func startsAtTimeAndReplacesLoopLikeGo() {
        let (_, presentation) = loadShow()
        let timetable = timetable()
        engine.go()
        timetable.start()
        #expect(timetable.nextStart == ScheduledStart(cueID: presentation.id, date: TimetableFixture.monday(14, 0)))
        clock.advance(by: 59)
        #expect(engine.state.content.frame?.cueID != presentation.id)
        clock.advance(by: 1)
        #expect(engine.state.content.frame?.cueID == presentation.id)
        #expect(engine.running.values.allSatisfy { $0.groupRun == nil })
        #expect(timetable.nextStart?.date == TimetableFixture.monday(14, 0).addingTimeInterval(24 * 3600))
    }

    @Test func disabledScheduleDoesNotStart() {
        let (_, presentation) = loadShow()
        let timetable = timetable(enabled: false)
        timetable.start()
        clock.advance(by: 120)
        #expect(engine.running[presentation.id] == nil)
    }

    @Test func missedTimeIsNotCaughtUp() {
        let (_, presentation) = loadShow()
        clock.advance(by: 5 * 60)
        let timetable = timetable()
        timetable.start()
        clock.advance(by: 30)
        #expect(engine.running[presentation.id] == nil)
    }

    @Test func pauseSkipsStartWithNotice() {
        let (_, presentation) = loadShow()
        let timetable = timetable()
        engine.go()
        engine.togglePause()
        timetable.start()
        clock.advance(by: 60)
        #expect(engine.running[presentation.id] == nil)
        #expect(timetable.skippedCueID == presentation.id)
    }

    @Test func startsAfterStopAll() {
        let (_, presentation) = loadShow()
        let timetable = timetable()
        engine.go()
        engine.stopAll()
        timetable.start()
        clock.advance(by: 60)
        #expect(engine.running[presentation.id] != nil)
    }
}
