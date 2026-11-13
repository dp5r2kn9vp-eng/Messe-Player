import Foundation

/// Brücke: Die alte Gruppen-Oberfläche liest und schreibt die Cue-Liste als `MediaGroup`/`Entry`.
/// IDs bleiben gleich (`MediaGroup.id` = `CueGroup.id`, `Entry.id` = `Cue.id`), Cue-Felder ohne Gegenstück bleiben erhalten.
nonisolated extension Project {
    var legacyGroups: [MediaGroup] {
        get { groups.map(legacyGroup) }
        set { applyLegacyGroups(newValue) }
    }

    @discardableResult
    mutating func addGroup() -> MediaGroup.ID {
        let group = CueGroup.empty(name: String(localized: "Gruppe \(groups.count + 1)"))
        groups.append(group)
        return group.id
    }

    /// Fügt Einträge an `index` (Standard: Ende) ein. Dasselbe Medium darf mehrfach vorkommen.
    mutating func addEntries(for mediumIDs: [Medium.ID], toGroup groupID: MediaGroup.ID, at index: Int? = nil) {
        var legacy = legacyGroups
        guard let groupIndex = legacy.firstIndex(where: { $0.id == groupID }) else { return }
        let count = legacy[groupIndex].entries.count
        let position = min(max(index ?? count, 0), count)
        let entries = mediumIDs.map { Entry(id: UUID(), mediumID: $0) }
        legacy[groupIndex].entries.insert(contentsOf: entries, at: position)
        legacyGroups = legacy
    }

    private func legacyGroup(_ group: CueGroup) -> MediaGroup {
        let members = cueRange(of: group).map { Array(cues[$0]) } ?? []
        return MediaGroup(id: group.id, name: group.name, entries: members.map(Entry.init(cue:)), crossfade: group.crossfade)
    }

    /// Ordnet die Cue-Liste nach den Gruppen neu; Cues außerhalb von Gruppen folgen am Ende.
    private mutating func applyLegacyGroups(_ legacy: [MediaGroup]) {
        let existingCues = Dictionary(cues.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingGroups = Dictionary(groups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let groupedIDs = Set(groups.compactMap(cueRange).flatMap { cues[$0].map(\.id) })
        var number = highestCueNumber

        var newCues: [Cue] = []
        var newGroups: [CueGroup] = []
        for mediaGroup in legacy {
            let members = mediaGroup.entries.map { entry in
                var cue: Cue
                if let existing = existingCues[entry.id] {
                    cue = existing
                } else {
                    number += 1
                    cue = Cue(id: entry.id, number: String(number), mediumID: entry.mediumID, outputID: outputs.first?.id)
                    cue.followAction = .followOnEnd
                }
                cue.layers = entry.layers
                cue.stillDuration = entry.imageDuration
                return cue
            }
            newCues += members
            var group = existingGroups[mediaGroup.id] ?? .empty(id: mediaGroup.id, name: mediaGroup.name)
            group.name = mediaGroup.name
            group.crossfade = mediaGroup.crossfade
            if let first = members.first, let last = members.last {
                group.firstCueID = first.id
                group.lastCueID = last.id
            } else {
                group = group.emptied()
            }
            newGroups.append(group)
        }
        let placedIDs = groupedIDs.union(newCues.map(\.id))
        cues = newCues + cues.filter { !placedIDs.contains($0.id) }
        groups = newGroups
    }
}

nonisolated extension Entry {
    init(cue: Cue) {
        // Steuer-Cues ohne Medium erscheinen als „Medium fehlt“.
        self.init(id: cue.id, mediumID: cue.mediumID ?? cue.id, layers: cue.layers, imageDuration: cue.stillDuration)
    }
}
