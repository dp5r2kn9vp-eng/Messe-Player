import Foundation

/// Aufbau des `.klangshow`-Pakets: `project.json` plus Ordner `Media/`.
/// Nach der Umstellung eines Projekts aus Format 1 liegt zusätzlich die Sicherung `project.v1.json` darin.
nonisolated enum ProjectPackage {
    static let projectFileName = "project.json"
    static let v1BackupFileName = "project.v1.json"
    static let mediaFolderName = "Media"

    static func read(_ package: FileWrapper) throws -> (Project, MediaStore) {
        let files = package.fileWrappers?[mediaFolderName]?.fileWrappers ?? [:]
        return (try ProjectCodec.decode(projectData(in: package)), MediaStore(files: files))
    }

    static func write(_ project: Project, media: MediaStore, v1Backup: Data? = nil) throws -> FileWrapper {
        var files = [
            projectFileName: FileWrapper(regularFileWithContents: try ProjectCodec.encode(project)),
            mediaFolderName: media.folderWrapper(for: project.media),
        ]
        if let v1Backup {
            files[v1BackupFileName] = FileWrapper(regularFileWithContents: v1Backup)
        }
        return FileWrapper(directoryWithFileWrappers: files)
    }

    /// Sicherung des Formats 1: eine bereits angelegte `project.v1.json` oder die noch nicht umgestellte `project.json`.
    static func v1Backup(in package: FileWrapper) -> Data? {
        if let backup = package.fileWrappers?[v1BackupFileName]?.regularFileContents { return backup }
        return isFormat1(package) ? package.fileWrappers?[projectFileName]?.regularFileContents : nil
    }

    /// `true`, solange `project.json` noch im Format 1 vorliegt (wird beim nächsten Speichern umgestellt).
    static func isFormat1(_ package: FileWrapper) -> Bool {
        guard let data = try? projectData(in: package) else { return false }
        return (try? ProjectCodec.schemaVersion(of: data)) == 1
    }

    private static func projectData(in package: FileWrapper) throws -> Data {
        guard let data = package.fileWrappers?[projectFileName]?.regularFileContents else {
            throw ProjectError.missingProjectFile
        }
        return data
    }
}
