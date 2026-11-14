import Foundation

/// Liest und schreibt `project.json` inklusive Prüfung und Migration der Schema-Version.
nonisolated enum ProjectCodec {
    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
    }

    /// Format 1: Gruppen mit Einträgen statt Cue-Liste.
    private struct ProjectV1: Decodable {
        var media: [Medium]?
        var groups: [V1Group]?
    }

    static func encode(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var stored = project
        stored.schemaVersion = project.requiredSchemaVersion
        return try encoder.encode(stored)
    }

    /// Im Speicher trägt ein Projekt immer die aktuelle Version.
    static func decode(_ data: Data) throws -> Project {
        let version = try schemaVersion(of: data)
        guard version <= Project.currentSchemaVersion else { throw ProjectError.newerSchema(version) }
        var project = try JSONDecoder().decode(Project.self, from: migrate(data, from: version))
        project.schemaVersion = Project.currentSchemaVersion
        return project
    }

    static func schemaVersion(of data: Data) throws -> Int {
        try JSONDecoder().decode(SchemaHeader.self, from: data).schemaVersion
    }

    /// Hebt ältere Formate schrittweise auf die aktuelle Version (n → n+1).
    private static func migrate(_ data: Data, from version: Int) throws -> Data {
        switch version {
        case Project.currentSchemaVersion: data
        // v2 → v3: nur neue, optionale Felder (Fade-/Stopp-Cues).
        case 2: data
        case 1: try migrate(migrateV1toV2(data), from: 2)
        default: throw ProjectError.unsupportedSchema(version)
        }
    }

    /// v1 → v2: Gruppen werden zu Loop-Gruppen über fortlaufend nummerierte Cues auf Ausgang 1.
    private static func migrateV1toV2(_ data: Data) throws -> Data {
        let old = try JSONDecoder().decode(ProjectV1.self, from: data)
        var project = Project()
        project.media = old.media ?? []
        let outputID = project.outputs.first?.id
        var number = 0
        for mediaGroup in old.groups ?? [] {
            let cues = mediaGroup.entries.map { entry in
                number += 1
                var cue = Cue(id: entry.id, number: String(number), mediumID: entry.mediumID, outputID: outputID)
                cue.stillDuration = entry.imageDuration
                cue.followAction = .followOnEnd
                cue.layers = entry.layers
                return cue
            }
            project.cues += cues
            var group = CueGroup.empty(id: mediaGroup.id, name: mediaGroup.name)
            group.crossfade = mediaGroup.crossfade
            if let first = cues.first, let last = cues.last {
                group.firstCueID = first.id
                group.lastCueID = last.id
            }
            project.groups.append(group)
        }
        return try encode(project)
    }
}
