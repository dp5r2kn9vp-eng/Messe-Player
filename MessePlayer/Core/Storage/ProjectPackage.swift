import Foundation

/// Aufbau des `.klangshow`-Pakets: `project.json` plus Ordner `Media/`.
nonisolated enum ProjectPackage {
    static let projectFileName = "project.json"
    static let mediaFolderName = "Media"

    static func read(_ package: FileWrapper) throws -> (Project, MediaStore) {
        guard let data = package.fileWrappers?[projectFileName]?.regularFileContents else {
            throw ProjectError.missingProjectFile
        }
        let files = package.fileWrappers?[mediaFolderName]?.fileWrappers ?? [:]
        return (try ProjectCodec.decode(data), MediaStore(files: files))
    }

    static func write(_ project: Project, media: MediaStore) throws -> FileWrapper {
        FileWrapper(directoryWithFileWrappers: [
            projectFileName: FileWrapper(regularFileWithContents: try ProjectCodec.encode(project)),
            mediaFolderName: media.folderWrapper(for: project.media),
        ])
    }
}
