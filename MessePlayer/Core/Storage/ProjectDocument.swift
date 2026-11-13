import SwiftUI
import UniformTypeIdentifiers

nonisolated extension UTType {
    static let klangShow = UTType(exportedAs: "de.klangniveau.klangshow")
}

/// Ein Messe-Projekt als Paket (`.klangshow`): ein Ordner, im Finder eine Datei.
nonisolated struct ProjectDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.klangShow]
    private static let projectFileName = "project.json"

    var project: Project

    init(project: Project = Project()) {
        self.project = project
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.fileWrappers?[Self.projectFileName]?.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        project = try JSONDecoder().decode(Project.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let projectFile = FileWrapper(regularFileWithContents: try encoder.encode(project))
        return FileWrapper(directoryWithFileWrappers: [Self.projectFileName: projectFile])
    }
}
