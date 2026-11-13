import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    static let klangShow = UTType(exportedAs: "de.klangniveau.klangshow")
}

/// Ein Messe-Projekt als Paket (`.klangshow`): ein Ordner, im Finder eine Datei. Aufbau siehe `ProjectPackage`.
nonisolated struct ProjectDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.klangShow]

    var project: Project
    var media: MediaStore

    init(project: Project = Project(), media: MediaStore = MediaStore()) {
        self.project = project
        self.media = media
    }

    init(configuration: ReadConfiguration) throws {
        (project, media) = try ProjectPackage.read(configuration.file)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try ProjectPackage.write(project, media: media)
    }
}

extension ProjectDocument {
    /// Nimmt Dateien an Position `index` der Bibliothek auf.
    /// Nicht unterstützte oder unlesbare Dateien werden übersprungen und als Fehler zurückgegeben.
    mutating func importMedia(from urls: [URL], at index: Int) -> [any Error] {
        var added: [Medium] = []
        var errors: [any Error] = []
        for url in urls {
            do {
                added.append(try media.add(url))
            } catch {
                errors.append(error)
            }
        }
        let position = min(max(index, 0), project.media.count)
        project.media.insert(contentsOf: added, at: position)
        return errors
    }
}
