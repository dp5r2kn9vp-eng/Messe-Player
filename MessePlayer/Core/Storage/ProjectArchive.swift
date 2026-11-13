import Foundation

nonisolated enum ArchiveError: LocalizedError, Equatable {
    case notSaved
    case unreadableArchive
    case noProjectInArchive

    var errorDescription: String? {
        switch self {
        case .notSaved:
            String(localized: "Bitte das Projekt zuerst speichern, dann exportieren.")
        case .unreadableArchive:
            String(localized: "Die Zip-Datei ist beschädigt oder kein gültiges Archiv.")
        case .noProjectInArchive:
            String(localized: "In der Zip-Datei wurde kein Messe-Player-Projekt (.klangshow) gefunden.")
        }
    }
}

/// Export und Import eines Projekts als `.zip` – zum Weitergeben oder Sichern.
nonisolated enum ProjectArchive {
    /// Packt das gespeicherte Paket samt Medien in eine Zip-Datei.
    /// Die Dateikoordination sorgt dafür, dass offene Änderungen vorher gespeichert werden.
    static func export(package: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: package, options: .forUploading, error: &coordinationError) { zipURL in
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: zipURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
    }

    /// Entpackt eine Zip-Datei in `folder`, prüft das enthaltene Projekt und liefert dessen Adresse.
    static func importArchive(_ archive: URL, into folder: URL) throws -> URL {
        let extraction = folder.appending(path: ".messe-player-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: extraction) }
        try unzip(archive, to: extraction)

        let contents = try FileManager.default.contentsOfDirectory(at: extraction, includingPropertiesForKeys: nil)
        guard let package = contents.first(where: { $0.pathExtension == "klangshow" }) else {
            throw ArchiveError.noProjectInArchive
        }
        // Prüft Aufbau und Schema-Version, bevor das Projekt übernommen wird.
        _ = try ProjectPackage.read(FileWrapper(url: package, options: []))

        let destination = uniqueURL(for: package.lastPathComponent, in: folder)
        try FileManager.default.moveItem(at: package, to: destination)
        return destination
    }

    private static func unzip(_ archive: URL, to folder: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ArchiveError.unreadableArchive }
    }

    /// „Show.klangshow“ → „Show 2.klangshow“ usw., falls der Name schon belegt ist.
    private static func uniqueURL(for fileName: String, in folder: URL) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = folder.appending(path: fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appending(path: "\(base) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
