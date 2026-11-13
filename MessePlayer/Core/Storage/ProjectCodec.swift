import Foundation

/// Liest und schreibt `project.json` inklusive Prüfung und Migration der Schema-Version.
nonisolated enum ProjectCodec {
    private struct SchemaHeader: Decodable {
        let schemaVersion: Int
    }

    static func encode(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(project)
    }

    static func decode(_ data: Data) throws -> Project {
        let version = try JSONDecoder().decode(SchemaHeader.self, from: data).schemaVersion
        guard version <= Project.currentSchemaVersion else { throw ProjectError.newerSchema(version) }
        return try JSONDecoder().decode(Project.self, from: migrate(data, from: version))
    }

    /// Hebt ältere Formate auf die aktuelle Version. Jede neue Schema-Version ergänzt hier einen Schritt n → n+1.
    private static func migrate(_ data: Data, from version: Int) throws -> Data {
        guard version < Project.currentSchemaVersion else { return data }
        throw ProjectError.unsupportedSchema(version)
    }
}
