import Foundation

/// Wurzel des gespeicherten Projekts (Schema 2: eine Cue-Liste). Ältere Formate hebt `ProjectCodec` an.
nonisolated struct Project: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion = Project.currentSchemaVersion
    var media: [Medium] = []
    var cues: [Cue] = []
    var groups: [CueGroup] = []
    var outputs: [OutputDefinition] = [.numbered(1)]

    init() {}

    /// Listen sind optional, damit Projekte ohne neuere Felder lesbar bleiben.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        media = try container.decodeIfPresent([Medium].self, forKey: .media) ?? []
        cues = try container.decodeIfPresent([Cue].self, forKey: .cues) ?? []
        groups = try container.decodeIfPresent([CueGroup].self, forKey: .groups) ?? []
        outputs = try container.decodeIfPresent([OutputDefinition].self, forKey: .outputs) ?? [.numbered(1)]
    }
}

/// Fehler, die `Project.validationIssues` meldet.
nonisolated enum ProjectIssue: Equatable {
    case groupBoundsMissing(CueGroup.ID)
    case groupReversed(CueGroup.ID)
    case groupsOverlap(CueGroup.ID, CueGroup.ID)
    case outputMissing(Cue.ID)
}

nonisolated extension Project {
    func medium(withID id: Medium.ID) -> Medium? {
        media.first { $0.id == id }
    }

    func cue(withID id: Cue.ID) -> Cue? {
        cues.first { $0.id == id }
    }

    /// Medien-IDs in der Reihenfolge der Bibliothek.
    func orderedMediumIDs(_ ids: Set<Medium.ID>) -> [Medium.ID] {
        media.filter { ids.contains($0.id) }.map(\.id)
    }

    /// Entfernt Medien samt aller Cues, die sie verwenden.
    mutating func removeMedia(_ ids: Set<Medium.ID>) {
        media.removeAll { ids.contains($0.id) }
        removeCues(Set(cues.filter { $0.mediumID.map(ids.contains) == true }.map(\.id)))
    }

    /// Entfernt Cues. Gruppengrenzen rücken nach; leer gewordene Gruppen werden zu leeren Gruppen.
    mutating func removeCues(_ ids: Set<Cue.ID>) {
        groups = groups.map { group in
            guard let range = cueRange(of: group) else { return group }
            let members = cues[range].filter { !ids.contains($0.id) }
            guard let first = members.first, let last = members.last else { return group.emptied() }
            var updated = group
            updated.firstCueID = first.id
            updated.lastCueID = last.id
            return updated
        }
        cues.removeAll { ids.contains($0.id) }
    }

    /// Nächste freie ganze Cue-Nummer nach der höchsten vorhandenen.
    func nextCueNumber() -> String {
        String(highestCueNumber + 1)
    }

    /// Höchste Cue-Nummer, abgerundet auf eine ganze Zahl (0 ohne numerische Nummern).
    var highestCueNumber: Int {
        Int((cues.compactMap { Double($0.number) }.max() ?? 0).rounded(.down))
    }

    /// Indizes der Cues einer Gruppe; `nil`, wenn sie leer ist, eine Grenze fehlt oder falsch herum liegt.
    func cueRange(of group: CueGroup) -> ClosedRange<Int>? {
        guard !group.isEmpty,
              let first = cues.firstIndex(where: { $0.id == group.firstCueID }),
              let last = cues.firstIndex(where: { $0.id == group.lastCueID }),
              first <= last
        else { return nil }
        return first...last
    }

    func group(containing cueID: Cue.ID) -> CueGroup? {
        guard let index = cues.firstIndex(where: { $0.id == cueID }) else { return nil }
        return groups.first { cueRange(of: $0)?.contains(index) == true }
    }

    /// Abgeleitete Dauer: Bild = Standdauer, Video/Audio = getrimmte Länge, Steuer-Cue = 0.
    /// `nil`, solange die Medienlänge unbekannt ist und kein Out-Punkt gesetzt wurde.
    func duration(of cue: Cue, mediaLength: TimeInterval?) -> TimeInterval? {
        guard let mediumID = cue.mediumID else { return 0 }
        if medium(withID: mediumID)?.kind == .image { return cue.stillDuration }
        guard let end = cue.outPoint ?? mediaLength else { return nil }
        return max(end - cue.inPoint, 0)
    }

    /// Prüft Gruppen (Grenzen vorhanden, richtig herum, nicht überlappend) und die Ausgänge der Cues.
    var validationIssues: [ProjectIssue] {
        var issues: [ProjectIssue] = []
        var ranges: [(id: CueGroup.ID, range: ClosedRange<Int>)] = []
        for group in groups where !group.isEmpty {
            guard let first = cues.firstIndex(where: { $0.id == group.firstCueID }),
                  let last = cues.firstIndex(where: { $0.id == group.lastCueID })
            else { issues.append(.groupBoundsMissing(group.id)); continue }
            guard first <= last else { issues.append(.groupReversed(group.id)); continue }
            for other in ranges where other.range.overlaps(first...last) {
                issues.append(.groupsOverlap(other.id, group.id))
            }
            ranges.append((group.id, first...last))
        }
        let outputIDs = Set(outputs.map(\.id))
        for cue in cues {
            if let outputID = cue.outputID, !outputIDs.contains(outputID) {
                issues.append(.outputMissing(cue.id))
            }
        }
        return issues
    }
}

nonisolated extension CueGroup {
    /// Leere Gruppe: beide Grenzen zeigen auf die eigene ID (z. B. aus einer leeren v1-Gruppe).
    /// Die Cue-Liste blendet leere Gruppen aus.
    static func empty(id: UUID = UUID(), name: String) -> CueGroup {
        CueGroup(id: id, name: name, firstCueID: id, lastCueID: id)
    }

    /// Dieselbe Gruppe ohne Cues (Einstellungen bleiben).
    func emptied() -> CueGroup {
        var group = self
        group.firstCueID = id
        group.lastCueID = id
        return group
    }

    var isEmpty: Bool { firstCueID == id && lastCueID == id }
}
