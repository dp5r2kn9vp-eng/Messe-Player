import Foundation

/// Eine Gruppe (Loop): geordnete Einträge, die nacheinander laufen.
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

/// Ein Platz in einer Gruppe. Verweist auf ein Medium; Bilder haben eine Standdauer, Videos laufen komplett.
nonisolated struct Entry: Codable, Equatable, Identifiable {
    static let defaultImageDuration: TimeInterval = 8
    static let durationRange: ClosedRange<TimeInterval> = 1...3600

    let id: UUID
    let mediumID: Medium.ID
    var layers: [Layer] = []
    var imageDuration: TimeInterval = Entry.defaultImageDuration {
        didSet { imageDuration = imageDuration.clamped(to: Self.durationRange) }
    }
}

extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
