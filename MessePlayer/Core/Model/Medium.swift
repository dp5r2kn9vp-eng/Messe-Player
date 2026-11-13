import Foundation
import UniformTypeIdentifiers

/// Ein Bild, Video oder Audio des Projekts. Die Datei liegt unter `fileName` im Ordner `Media/` des Pakets.
nonisolated struct Medium: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case image
        case video
        /// Audio-Cues ohne Ausgang (Systemausgabe).
        case audio

        /// `nil` für Dateitypen, die der Player nicht abspielen kann.
        init?(contentType: UTType) {
            if contentType.conforms(to: .image) {
                self = .image
            } else if contentType.conforms(to: .movie) {
                self = .video
            } else if contentType.conforms(to: .audio) {
                self = .audio
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
