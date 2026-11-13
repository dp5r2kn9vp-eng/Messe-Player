import Foundation

/// Gruppe im Projektformat 1; nur noch zum Lesen alter Projekte (`ProjectCodec.migrate`).
nonisolated struct V1Group: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var entries: [V1Entry] = []
    var crossfade: TimeInterval = CueGroup.defaultCrossfade
}

/// Ein Platz in einer v1-Gruppe; in Schema 2 ein `Cue` (gleiche ID).
nonisolated struct V1Entry: Codable, Equatable, Identifiable {
    let id: UUID
    let mediumID: Medium.ID
    var layers: [Layer] = []
    var imageDuration: TimeInterval = Cue.defaultStillDuration
}

/// Fehlende Felder bekommen Standardwerte, damit alle Dateien im Format 1 lesbar bleiben.
nonisolated extension V1Group {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        entries = try container.decodeIfPresent([V1Entry].self, forKey: .entries) ?? []
        crossfade = try container.decodeIfPresent(TimeInterval.self, forKey: .crossfade) ?? CueGroup.defaultCrossfade
    }
}

nonisolated extension V1Entry {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mediumID = try container.decode(UUID.self, forKey: .mediumID)
        layers = try container.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        imageDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .imageDuration) ?? Cue.defaultStillDuration
    }
}

extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
