import Foundation

nonisolated enum ProjectError: LocalizedError, Equatable {
    case missingProjectFile
    case newerSchema(Int)
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .missingProjectFile:
            String(localized: "Die Projektdatei ist beschädigt: project.json fehlt.")
        case .newerSchema(let version):
            String(localized: "Dieses Projekt stammt aus einer neueren Version des Messe-Players (Format \(version)). Bitte die App aktualisieren.")
        case .unsupportedSchema(let version):
            String(localized: "Das Projektformat \(version) wird nicht unterstützt.")
        }
    }
}

nonisolated enum MediaError: LocalizedError, Equatable {
    case unsupportedType(fileName: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let fileName):
            String(localized: "„\(fileName)“ ist kein unterstütztes Bild- oder Videoformat.")
        }
    }
}
