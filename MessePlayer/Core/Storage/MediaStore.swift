import Foundation
import UniformTypeIdentifiers

/// Einziger Zugriff auf die Mediendateien eines Projekts.
/// Dateien werden erst beim Speichern ins Paket geschrieben und bis dahin lazy von der Quelle gelesen,
/// damit große Videos nicht im Speicher landen.
nonisolated struct MediaStore {
    private var files: [String: FileWrapper]
    /// Neu aufgenommene Dateien, die noch nicht im gespeicherten Paket liegen.
    private var pendingSources: [String: URL] = [:]

    init(files: [String: FileWrapper] = [:]) {
        self.files = files
    }

    /// Nimmt eine Datei auf. Sie wird beim nächsten Speichern nach `Media/` kopiert.
    mutating func add(_ source: URL) throws -> Medium {
        guard let type = UTType(filenameExtension: source.pathExtension),
              let kind = Medium.Kind(contentType: type)
        else { throw MediaError.unsupportedType(fileName: source.lastPathComponent) }

        let id = UUID()
        let fileName = "\(id.uuidString).\(source.pathExtension.lowercased())"
        let file = try FileWrapper(url: source, options: [])
        // Sonst schreibt FileWrapper die Datei unter ihrem Originalnamen ins Paket.
        file.preferredFilename = fileName
        files[fileName] = file
        pendingSources[fileName] = source
        return Medium(id: id, kind: kind, fileName: fileName, displayName: source.lastPathComponent)
    }

    /// Abspielbare Adresse eines Mediums – im gespeicherten Paket oder, vor dem ersten Speichern, an der Quelle.
    func url(for medium: Medium, in packageURL: URL?) -> URL? {
        if let source = pendingSources[medium.fileName] { return source }
        return packageURL?
            .appending(path: ProjectPackage.mediaFolderName)
            .appending(path: medium.fileName)
    }

    /// Ordner `Media/` mit genau den Dateien, die das Projekt noch verwendet.
    func folderWrapper(for media: [Medium]) -> FileWrapper {
        let used = Set(media.map(\.fileName))
        return FileWrapper(directoryWithFileWrappers: files.filter { used.contains($0.key) })
    }
}
