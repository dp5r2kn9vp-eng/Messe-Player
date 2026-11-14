import Foundation

/// Fester Start eines Cues zur Uhrzeit (Ortszeit), täglich oder an bestimmten Wochentagen.
nonisolated struct CueSchedule: Codable, Equatable {
    static let minuteRange = 0...(24 * 60 - 1)

    /// Minuten nach Mitternacht.
    var minuteOfDay: Int {
        didSet { minuteOfDay = minuteOfDay.clamped(to: Self.minuteRange) }
    }
    /// Wochentage wie in `Calendar` (1 = Sonntag … 7 = Samstag); leer = täglich.
    var weekdays: Set<Int> = []

    init(minuteOfDay: Int, weekdays: Set<Int> = []) {
        self.minuteOfDay = minuteOfDay.clamped(to: Self.minuteRange)
        self.weekdays = weekdays
    }

    var hour: Int { minuteOfDay / 60 }
    var minute: Int { minuteOfDay % 60 }

    /// Startzeiten im Zeitraum (`start`, `end`].
    func occurrences(after start: Date, through end: Date, calendar: Calendar) -> [Date] {
        guard end > start else { return [] }
        var dates: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day <= end {
            if let date = occurrence(on: day, calendar: calendar), date > start, date <= end {
                dates.append(date)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return dates
    }

    /// Nächste Startzeit nach `date` (höchstens eine Woche voraus).
    func nextOccurrence(after date: Date, calendar: Calendar) -> Date? {
        guard let limit = calendar.date(byAdding: .day, value: 8, to: date) else { return nil }
        return occurrences(after: date, through: limit, calendar: calendar).first
    }

    private func occurrence(on day: Date, calendar: Calendar) -> Date? {
        guard weekdays.isEmpty || weekdays.contains(calendar.component(.weekday, from: day)) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}
