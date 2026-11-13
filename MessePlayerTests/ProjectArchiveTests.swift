import Foundation
import Testing
@testable import MessePlayer

struct ProjectArchiveTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private func makePackage() throws -> (URL, Project) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appending(path: "Clip.mov")
        try Data("video".utf8).write(to: source)
        var media = MediaStore()
        var project = Project()
        project.media = [try media.add(source)]
        let groupID = project.addGroup()
        project.addEntries(for: project.media.map(\.id), toGroup: groupID)
        let package = directory.appending(path: "Messe.klangshow")
        try ProjectPackage.write(project, media: media).write(to: package, options: .atomic, originalContentsURL: nil)
        return (package, project)
    }

    @Test func exportThenImportIsIdentical() throws {
        let (package, project) = try makePackage()
        let zip = directory.appending(path: "Messe.zip")
        try ProjectArchive.export(package: package, to: zip)

        let target = directory.appending(path: "Import")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let imported = try ProjectArchive.importArchive(zip, into: target)
        let (reopened, media) = try ProjectPackage.read(FileWrapper(url: imported, options: []))

        #expect(imported.lastPathComponent == "Messe.klangshow")
        #expect(reopened == project)
        let url = try #require(media.url(for: reopened.media[0], in: imported))
        #expect(try Data(contentsOf: url) == Data("video".utf8))
    }

    @Test func importDoesNotOverwriteExistingProject() throws {
        let (package, _) = try makePackage()
        let zip = directory.appending(path: "Messe.zip")
        try ProjectArchive.export(package: package, to: zip)
        let imported = try ProjectArchive.importArchive(zip, into: directory)
        #expect(imported.lastPathComponent == "Messe 2.klangshow")
    }

    @Test func rejectsBrokenArchive() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let zip = directory.appending(path: "kaputt.zip")
        try Data("kein zip".utf8).write(to: zip)
        #expect(throws: ArchiveError.unreadableArchive) { try ProjectArchive.importArchive(zip, into: directory) }
    }

    @Test func rejectsArchiveWithoutProject() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let folder = directory.appending(path: "Fotos")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appending(path: "bild.jpg"))
        let zip = directory.appending(path: "Fotos.zip")
        try ProjectArchive.export(package: folder, to: zip)
        #expect(throws: ArchiveError.noProjectInArchive) { try ProjectArchive.importArchive(zip, into: directory) }
    }
}
