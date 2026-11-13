import Foundation
import Testing
@testable import MessePlayer

struct MediaImportTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private func makeFiles(_ names: [String]) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try names.map { name in
            let url = directory.appending(path: name)
            try Data(name.utf8).write(to: url)
            return url
        }
    }

    @Test func insertsAtDropPositionAndKeepsOrder() throws {
        var document = ProjectDocument()
        _ = document.importMedia(from: try makeFiles(["A.png", "B.png"]), at: 0)
        _ = document.importMedia(from: try makeFiles(["X.mov", "Y.jpg"]), at: 1)
        #expect(document.project.media.map(\.displayName) == ["A.png", "X.mov", "Y.jpg", "B.png"])
    }

    @Test func skipsUnsupportedFilesAndReportsThem() throws {
        var document = ProjectDocument()
        let errors = document.importMedia(from: try makeFiles(["Clip.mp4", "Liste.pdf", "Foto.heic"]), at: 0)
        #expect(document.project.media.map(\.kind) == [.video, .image])
        #expect(errors.errors.count == 1)
        #expect(errors.errors.first as? MediaError == .unsupportedType(fileName: "Liste.pdf"))
    }

    @Test func clampsOutOfRangePosition() throws {
        var document = ProjectDocument()
        _ = document.importMedia(from: try makeFiles(["A.png"]), at: 42)
        #expect(document.project.media.count == 1)
    }
}
