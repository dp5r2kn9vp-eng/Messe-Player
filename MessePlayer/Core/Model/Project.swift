import Foundation

/// Wurzel des gespeicherten Projekts. `schemaVersion` ermöglicht spätere Migrationen (`ProjectCodec`).
nonisolated struct Project: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = Project.currentSchemaVersion
    var media: [Medium] = []
    var groups: [MediaGroup] = []

    init() {}

    /// Listen sind optional, damit Projekte ohne neuere Felder lesbar bleiben.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        media = try container.decodeIfPresent([Medium].self, forKey: .media) ?? []
        groups = try container.decodeIfPresent([MediaGroup].self, forKey: .groups) ?? []
    }
}

extension Project {
    func medium(withID id: Medium.ID) -> Medium? {
        media.first { $0.id == id }
    }

    /// Entfernt Medien samt aller Gruppeneinträge, die sie verwenden.
    mutating func removeMedia(_ ids: Set<Medium.ID>) {
        media.removeAll { ids.contains($0.id) }
        for index in groups.indices {
            groups[index].entries.removeAll { ids.contains($0.mediumID) }
        }
    }

    /// Medien-IDs in der Reihenfolge der Bibliothek.
    func orderedMediumIDs(_ ids: Set<Medium.ID>) -> [Medium.ID] {
        media.filter { ids.contains($0.id) }.map(\.id)
    }

    @discardableResult
    mutating func addGroup() -> MediaGroup.ID {
        let group = MediaGroup(id: UUID(), name: String(localized: "Gruppe \(groups.count + 1)"))
        groups.append(group)
        return group.id
    }

    /// Fügt Einträge an `index` (Standard: Ende) ein. Dasselbe Medium darf mehrfach vorkommen.
    mutating func addEntries(for mediumIDs: [Medium.ID], toGroup groupID: MediaGroup.ID, at index: Int? = nil) {
        guard let groupIndex = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let count = groups[groupIndex].entries.count
        let position = min(max(index ?? count, 0), count)
        let entries = mediumIDs.map { Entry(id: UUID(), mediumID: $0) }
        groups[groupIndex].entries.insert(contentsOf: entries, at: position)
    }
}
