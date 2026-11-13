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
    /// Sicherung eines aus Format 1 umgestellten Projekts; wird bei jedem Speichern mitgeschrieben.
    private(set) var v1Backup: Data?
    /// `true`, wenn die Datei noch im Format 1 vorliegt und beim Speichern umgestellt wird.
    private(set) var isConvertedFromFormat1 = false

    init(project: Project = Project(), media: MediaStore = MediaStore()) {
        self.project = project
        self.media = media
    }

    init(configuration: ReadConfiguration) throws {
        (project, media) = try ProjectPackage.read(configuration.file)
        v1Backup = ProjectPackage.v1Backup(in: configuration.file)
        isConvertedFromFormat1 = ProjectPackage.isFormat1(configuration.file)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try ProjectPackage.write(project, media: media, v1Backup: v1Backup)
    }
}

/// Ergebnis eines Imports: übernommene Medien und übersprungene Dateien.
nonisolated struct ImportResult {
    var added: [Medium] = []
    var errors: [any Error] = []
}

extension ProjectDocument {
    /// Nimmt Dateien an Position `index` der Bibliothek auf.
    /// Nicht unterstützte oder unlesbare Dateien werden übersprungen und als Fehler zurückgegeben.
    @discardableResult
    mutating func importMedia(from urls: [URL], at index: Int) -> ImportResult {
        var result = ImportResult()
        for url in urls {
            do {
                result.added.append(try media.add(url))
            } catch {
                result.errors.append(error)
            }
        }
        let position = min(max(index, 0), project.media.count)
        project.media.insert(contentsOf: result.added, at: position)
        return result
    }

    func playable(_ medium: Medium, in packageURL: URL?) -> PlayableMedium? {
        media.url(for: medium, in: packageURL).map { PlayableMedium(medium: medium, url: $0) }
    }

    func renderLayers(_ layers: [Layer], in packageURL: URL?) -> [RenderLayer] {
        layers.map { layer in
            guard case .image(let mediumID) = layer.content else { return RenderLayer(layer: layer, imageURL: nil) }
            let url = project.medium(withID: mediumID).flatMap { media.url(for: $0, in: packageURL) }
            return RenderLayer(layer: layer, imageURL: url)
        }
    }

    /// Löst eine Gruppe zum Abspielen auf; Einträge ohne Medium werden übersprungen.
    func playlist(for group: MediaGroup, in packageURL: URL?) -> LoopPlaylist {
        let items = group.entries.compactMap { entry -> LoopItem? in
            guard let medium = project.medium(withID: entry.mediumID),
                  let item = playable(medium, in: packageURL)
            else { return nil }
            return LoopItem(entryID: entry.id, item: item, imageDuration: entry.imageDuration, layers: renderLayers(entry.layers, in: packageURL))
        }
        return LoopPlaylist(groupID: group.id, crossfade: group.crossfade, items: items)
    }
}
