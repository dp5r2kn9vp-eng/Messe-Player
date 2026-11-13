import Foundation
import UniformTypeIdentifiers

/// Ein Bild oder Video des Projekts. Die Datei liegt unter `fileName` im Ordner `Media/` des Pakets.
nonisolated struct Medium: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case image
        case video

        /// `nil` für Dateitypen, die der Player nicht abspielen kann.
        init?(contentType: UTType) {
            if contentType.conforms(to: .image) {
                self = .image
            } else if contentType.conforms(to: .movie) {
                self = .video
            } else {
                return nil
            }
        }
    }

    let id: UUID
    let kind: Kind
    /// Eindeutiger Name im Paket, unabhängig vom Originalnamen.
    let fileName: String
    /// Ursprünglicher Dateiname zur Anzeige.
    var displayName: String
}
