import Foundation

/// Wurzel des gespeicherten Projekts. `schemaVersion` ermöglicht spätere Migrationen.
nonisolated struct Project: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = Project.currentSchemaVersion
}
