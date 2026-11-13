import Foundation

/// Gruppe im Format v1 und Sicht der alten Gruppen-Oberfläche auf die Cue-Liste (siehe `Project.legacyGroups`).
/// Entfällt, sobald Cue-Liste und Cue-Engine die alte Oberfläche ersetzen.
nonisolated struct MediaGroup: Codable, Equatable, Identifiable {
    static let defaultCrossfade: TimeInterval = 0.5
    static let crossfadeRange: ClosedRange<TimeInterval> = 0...5

    let id: UUID
    var name: String
    var entries: [Entry] = []
    /// Überblendzeit zwischen den Einträgen in Sekunden (0 = harter Schnitt).
    var crossfade: TimeInterval = MediaGroup.defaultCrossfade {
        didSet { crossfade = crossfade.clamped(to: Self.crossfadeRange) }
    }
}

/// Ein Platz in einer v1-Gruppe; in Schema 2 ein `Cue` (gleiche ID).
nonisolated struct Entry: Codable, Equatable, Identifiable {
    static let defaultImageDuration: TimeInterval = Cue.defaultStillDuration
    static let durationRange: ClosedRange<TimeInterval> = 1...3600

    let id: UUID
    let mediumID: Medium.ID
    var layers: [Layer] = []
    var imageDuration: TimeInterval = Entry.defaultImageDuration {
        didSet { imageDuration = imageDuration.clamped(to: Self.durationRange) }
    }
}

/// Fehlende neuere Felder bekommen Standardwerte, damit ältere Projektdateien lesbar bleiben.
nonisolated extension MediaGroup {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        entries = try container.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        crossfade = try container.decodeIfPresent(TimeInterval.self, forKey: .crossfade) ?? Self.defaultCrossfade
    }
}

nonisolated extension MediaGroup {
    /// Setzt die Standdauer für mehrere Einträge auf einmal, z. B. für eine Mehrfachauswahl.
    /// Videos ignorieren den Wert, weil sie immer komplett laufen.
    mutating func setImageDuration(_ seconds: TimeInterval, for ids: Set<Entry.ID>) {
        for index in entries.indices where ids.contains(entries[index].id) {
            entries[index].imageDuration = seconds
        }
    }
}

nonisolated extension Entry {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mediumID = try container.decode(UUID.self, forKey: .mediumID)
        layers = try container.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        imageDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .imageDuration) ?? Self.defaultImageDuration
    }
}

extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
