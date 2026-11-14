import SwiftUI

/// Start zur Uhrzeit: Schalter, Uhrzeit und Wochentage (leer = täglich).
struct ScheduleEditor: View {
    let schedule: CueSchedule?
    let onChange: (CueSchedule?) -> Void

    /// Vorschlag beim Einschalten.
    static let defaultSchedule = CueSchedule(minuteOfDay: 14 * 60)

    var body: some View {
        Toggle("Startet um Uhrzeit", isOn: Binding(
            get: { schedule != nil },
            set: { onChange($0 ? Self.defaultSchedule : nil) }
        ))
        .help("Startet den Cue zur Uhrzeit wie GO – im Messe-Modus oder mit „Zeitplan aktiv“ (Menü Wiedergabe)")
        if let schedule {
            DatePicker("Uhrzeit", selection: time(of: schedule), displayedComponents: .hourAndMinute)
            LabeledContent("Tage") {
                weekdayButtons(schedule)
            }
            .help("Keine Auswahl = täglich")
        }
    }

    private func time(of schedule: CueSchedule) -> Binding<Date> {
        let calendar = Calendar.current
        return Binding(
            get: { calendar.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: .now) ?? .now },
            set: { date in
                var changed = schedule
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                changed.minuteOfDay = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                onChange(changed)
            }
        )
    }

    /// Mo–So in der Reihenfolge des Kalenders (Montag zuerst in Deutschland).
    private func weekdayButtons(_ schedule: CueSchedule) -> some View {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack(spacing: Theme.Spacing.xs) {
            ForEach(order, id: \.self) { weekday in
                Toggle(symbols[weekday - 1], isOn: Binding(
                    get: { schedule.weekdays.contains(weekday) },
                    set: { isOn in
                        var changed = schedule
                        if isOn { changed.weekdays.insert(weekday) } else { changed.weekdays.remove(weekday) }
                        onChange(changed)
                    }
                ))
                .toggleStyle(.button)
            }
        }
    }
}

extension CueSchedule {
    /// „14:00“ bzw. „14:00 Mo, Di“.
    var summary: String {
        let time = String(format: "%02d:%02d", hour, minute)
        guard !weekdays.isEmpty else { return time }
        let calendar = Calendar.current
        let days = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
            .filter(weekdays.contains)
            .map { calendar.shortStandaloneWeekdaySymbols[$0 - 1] }
        return "\(time) \(days.joined(separator: ", "))"
    }
}
