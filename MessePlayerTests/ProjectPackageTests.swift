import Foundation
import Testing
@testable import MessePlayer

struct ProjectPackageTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private func makeSource(_ name: String, contents: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func save(_ project: Project, _ media: MediaStore, as name: String) throws -> URL {
        let url = directory.appending(path: name)
        try ProjectPackage.write(project, media: media).write(to: url, options: .atomic, originalContentsURL: nil)
        return url
    }

    private func open(_ url: URL) throws -> (Project, MediaStore) {
        try ProjectPackage.read(FileWrapper(url: url, options: []))
    }

    @Test func saveAndOpenIsLossless() throws {
        var media = MediaStore()
        var project = Project()
        project.media = [
            try media.add(makeSource("Logo.png", contents: "bild")),
            try media.add(makeSource("Clip.mov", contents: "video")),
        ]

        let firstURL = try save(project, media, as: "Erst.klangshow")
        let (reopened, reopenedMedia) = try open(firstURL)
        #expect(reopened == project)
        #expect(reopened.media.map(\.kind) == [.image, .video])

        // Zweites Speichern aus dem geöffneten Paket muss die Medien weiterhin enthalten.
        let secondURL = try save(reopened, reopenedMedia, as: "Zweit.klangshow")
        let (_, secondMedia) = try open(secondURL)
        let contents = try project.media.map { medium in
            let url = try #require(secondMedia.url(for: medium, in: secondURL))
            return String(decoding: try Data(contentsOf: url), as: UTF8.self)
        }
        #expect(contents == ["bild", "video"])
    }

    @Test func pendingMediumIsPlayableBeforeFirstSave() throws {
        var media = MediaStore()
        let source = try makeSource("Clip.mp4", contents: "video")
        let medium = try media.add(source)
        #expect(media.url(for: medium, in: nil) == source)
    }

    @Test func removedMediaAreNotWritten() throws {
        var media = MediaStore()
        _ = try media.add(makeSource("Alt.jpg", contents: "weg"))
        let url = try save(Project(), media, as: "Leer.klangshow")
        let files = try FileManager.default.contentsOfDirectory(atPath: url.appending(path: ProjectPackage.mediaFolderName).path)
        #expect(files.isEmpty)
    }

    @Test func rejectsUnsupportedFiles() throws {
        var media = MediaStore()
        let source = try makeSource("Notizen.txt", contents: "text")
        #expect(throws: MediaError.unsupportedType(fileName: "Notizen.txt")) { try media.add(source) }
    }
}
