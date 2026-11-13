import Foundation

/// Wurzel des gespeicherten Projekts. `schemaVersion` ermöglicht spätere Migrationen (`ProjectCodec`).
nonisolated struct Project: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = Project.currentSchemaVersion
    var media: [Medium] = []
}
