import Foundation
import Testing
@testable import MessePlayer

/// Migration Format 1 → 2 und Sicherung `project.v1.json`.
struct MigrationTests {
    /// Datei im Format 1, aus den alten Typen erzeugt.
    private struct FileV1: Encodable {
        var schemaVersion = 1
        var media: [Medium]
        var groups: [V1Group]
    }

    private let image = Medium(id: UUID(), kind: .image, fileName: "a.png", displayName: "A")
    private let video = Medium(id: UUID(), kind: .video, fileName: "b.mov", displayName: "B")

    private func fixture() throws -> (FileV1, Data) {
        var animated = Layer.text("Willkommen")
        animated.animation.entrance = .slideUp
        animated.animation.effect = .pulse
        animated.animation.visibleFor = 4
        var first = V1Group(id: UUID(), name: "Begrüßung", crossfade: 1)
        first.entries = [
            V1Entry(id: UUID(), mediumID: image.id, layers: [animated, .logo()], imageDuration: 12),
            V1Entry(id: UUID(), mediumID: video.id),
        ]
        var second = V1Group(id: UUID(), name: "Pause", crossfade: 0)
        second.entries = [V1Entry(id: UUID(), mediumID: image.id, layers: [.image(image.id)], imageDuration: 3)]
        let empty = V1Group(id: UUID(), name: "Leer")
        let file = FileV1(media: [image, video], groups: [first, second, empty])
        return (file, try JSONEncoder().encode(file))
    }

    @Test func migratesGroupsToNumberedLoopCuesOnOutputOne() throws {
        let (file, data) = try fixture()
        let project = try ProjectCodec.decode(data)
        let entries = file.groups.flatMap(\.entries)
        let outputID = try #require(project.outputs.first?.id)

        #expect(project.schemaVersion == 2)
        #expect(project.media == file.media)
        #expect(project.outputs.count == 1)
        #expect(project.cues.map(\.id) == entries.map(\.id))
        #expect(project.cues.map(\.number) == ["1", "2", "3"])
        #expect(project.cues.map(\.mediumID) == entries.map(\.mediumID))
        #expect(project.cues.map(\.layers) == entries.map(\.layers))
        #expect(project.cues.map(\.stillDuration) == [12, Cue.defaultStillDuration, 3])
        #expect(project.cues.allSatisfy { $0.followAction == .followOnEnd && $0.outputID == outputID })
        #expect(project.cues.allSatisfy { $0.wait == 0 && $0.volume == 1 && $0.fadeIn == 0 && $0.fadeOut == 0 })
        #expect(project.cues.allSatisfy { $0.inPoint == 0 && $0.outPoint == nil && $0.notes.isEmpty && $0.color == nil })
        #expect(project.validationIssues.isEmpty)
    }

    @Test func migratesGroupSettingsAndBounds() throws {
        let (file, data) = try fixture()
        let project = try ProjectCodec.decode(data)
        #expect(project.groups.map(\.id) == file.groups.map(\.id))
        #expect(project.groups.map(\.name) == ["Begrüßung", "Pause", "Leer"])
        #expect(project.groups.map(\.crossfade) == [1, 0, CueGroup.defaultCrossfade])
        #expect(project.groups.allSatisfy { $0.mode == .loop && !$0.isCollapsed })
        #expect(project.groups.map { project.cueRange(of: $0) } == [0...1, 2...2, nil])
        #expect(project.groups[2].isEmpty)
    }

    @Test func realLegacyProjectLoadsWithoutLoss() throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "hochzeitsmesse-v1", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rawGroups = try #require(raw["groups"] as? [[String: Any]])
        let rawEntries = rawGroups.flatMap { ($0["entries"] as? [[String: Any]]) ?? [] }

        let project = try ProjectCodec.decode(data)
        #expect(project.media.count == (raw["media"] as? [Any])?.count)
        #expect(project.groups.count == rawGroups.count)
        #expect(project.cues.map(\.id.uuidString) == rawEntries.compactMap { $0["id"] as? String })
        #expect(project.cues.map(\.stillDuration) == rawEntries.compactMap { $0["imageDuration"] as? Double })
        #expect(project.validationIssues.isEmpty)
        #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)
    }

    @Test func savingFormat1KeepsBackupInPackage() throws {
        let (_, data) = try fixture()
        let v1 = FileWrapper(directoryWithFileWrappers: [ProjectPackage.projectFileName: FileWrapper(regularFileWithContents: data)])
        #expect(ProjectPackage.isFormat1(v1))
        let backup = try #require(ProjectPackage.v1Backup(in: v1))

        let (project, media) = try ProjectPackage.read(v1)
        let saved = try ProjectPackage.write(project, media: media, v1Backup: backup)
        #expect(saved.fileWrappers?[ProjectPackage.v1BackupFileName]?.regularFileContents == data)
        #expect(!ProjectPackage.isFormat1(saved))
        #expect(ProjectPackage.v1Backup(in: saved) == data)
        #expect(try ProjectPackage.read(saved).0 == project)
    }

    @Test func newProjectsHaveNoBackup() throws {
        let saved = try ProjectPackage.write(Project(), media: MediaStore())
        #expect(saved.fileWrappers?[ProjectPackage.v1BackupFileName] == nil)
        #expect(ProjectPackage.v1Backup(in: saved) == nil)
        #expect(!ProjectPackage.isFormat1(saved))
    }
}

private final class BundleToken {}
