import Foundation

/// Anordnung des Zeitstrahls: Spuren (Ausgänge in Projekt-Reihenfolge, dann Ton) mit überschneidungsfreien Zeilen.
struct TimelineLayout: Equatable {
    struct Lane: Equatable, Identifiable {
        let lane: TimelineLane
        /// Index des Ausgangs für die Kennfarbe; `nil` = Tonspur.
        let outputIndex: Int?
        let name: String
        var rows: [[TimelineItem]] = []

        var id: TimelineLane { lane }
    }

    let lanes: [Lane]
    /// Dargestellte Länge in Sekunden; offene Balken reichen bis hierhin.
    let length: TimeInterval
    let goTimes: [TimeInterval]

    /// Nachlauf hinter dem letzten Ereignis, damit offene Balken als offen erkennbar sind.
    static let tail: TimeInterval = 5
    static let minimumLength: TimeInterval = 30

    init(timeline: ShowTimeline, outputs: [OutputDefinition]) {
        length = max(timeline.lastEvent + Self.tail, Self.minimumLength)
        goTimes = timeline.goTimes
        let items = timeline.bars.map(TimelineItem.bar) + timeline.loops.map(TimelineItem.loop)
        var lanes = outputs.enumerated().map { index, output in
            Lane(lane: .output(output.id), outputIndex: index, name: output.name)
        }
        lanes.append(Lane(lane: .audio, outputIndex: nil, name: String(localized: "Ton")))
        let length = length
        self.lanes = lanes.map { lane in
            var packed = lane
            packed.rows = Self.pack(items.filter { $0.lane == lane.lane }, length: length)
            return packed
        }
    }

    /// Verteilt Einträge auf möglichst wenige Zeilen ohne Überschneidung (früheste freie Zeile).
    static func pack(_ items: [TimelineItem], length: TimeInterval) -> [[TimelineItem]] {
        var rows: [[TimelineItem]] = []
        var rowEnds: [TimeInterval] = []
        for item in items.sorted(by: { ($0.start, $0.end(in: length)) < ($1.start, $1.end(in: length)) }) {
            if let row = rowEnds.firstIndex(where: { $0 <= item.start }) {
                rows[row].append(item)
                rowEnds[row] = item.end(in: length)
            } else {
                rows.append([item])
                rowEnds.append(item.end(in: length))
            }
        }
        return rows.isEmpty ? [[]] : rows
    }
}

/// Ein Eintrag im Zeitstrahl: Cue-Balken oder Wiederholungs-Abschnitt einer Gruppe.
enum TimelineItem: Equatable, Identifiable {
    case bar(TimelineBar)
    case loop(TimelineLoop)

    var id: String {
        switch self {
        case .bar(let bar): bar.id
        case .loop(let loop): loop.id
        }
    }

    var lane: TimelineLane {
        switch self {
        case .bar(let bar): bar.lane
        case .loop(let loop): loop.lane
        }
    }

    var start: TimeInterval {
        switch self {
        case .bar(let bar): bar.start
        case .loop(let loop): loop.start
        }
    }

    /// Rechter Rand; offene Einträge reichen bis `length`.
    func end(in length: TimeInterval) -> TimeInterval {
        switch self {
        case .bar(let bar): bar.visibleUntil ?? length
        case .loop(let loop): loop.end ?? length
        }
    }
}
