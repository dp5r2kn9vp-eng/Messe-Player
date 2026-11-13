import Foundation
import Testing
@testable import MessePlayer

struct GroupTests {
    private func project(media names: [String]) -> Project {
        var project = Project()
        project.media = names.map { Medium(id: UUID(), kind: .image, fileName: $0, displayName: $0) }
        return project
    }

    @Test func addsEntriesInLibraryOrderAndAllowsDuplicates() throws {
        var project = project(media: ["A", "B", "C"])
        let groupID = project.addGroup()
        let ids = project.orderedMediumIDs(Set([project.media[2].id, project.media[0].id]))
        project.addEntries(for: ids, toGroup: groupID)
        project.addEntries(for: [project.media[0].id], toGroup: groupID, at: 1)

        let names = try #require(project.groups.first).entries.compactMap { project.medium(withID: $0.mediumID)?.displayName }
        #expect(names == ["A", "A", "C"])
    }

    @Test func newGroupsAreNumbered() {
        var project = Project()
        project.addGroup()
        project.addGroup()
        #expect(project.groups.map(\.name) == ["Gruppe 1", "Gruppe 2"])
    }

    @Test func removingMediumRemovesItsEntries() throws {
        var project = project(media: ["A", "B"])
        let groupID = project.addGroup()
        project.addEntries(for: project.media.map(\.id), toGroup: groupID)
        project.removeMedia([project.media[0].id])
        #expect(try #require(project.groups.first).entries.count == 1)
    }

    @Test func imageDurationIsClampedAndDefaulted() {
        var entry = Entry(id: UUID(), mediumID: UUID())
        #expect(entry.imageDuration == Entry.defaultImageDuration)
        entry.imageDuration = 0
        #expect(entry.imageDuration == Entry.durationRange.lowerBound)
        entry.imageDuration = 99_999
        #expect(entry.imageDuration == Entry.durationRange.upperBound)
    }

    @Test func groupsSurviveSaveRoundTripAndOldFilesStillOpen() throws {
        var project = project(media: ["A"])
        let groupID = project.addGroup()
        project.addEntries(for: [project.media[0].id], toGroup: groupID)
        project.groups[0].entries[0].imageDuration = 12
        #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)

        let legacy = Data(#"{"schemaVersion": 1, "media": []}"#.utf8)
        #expect(try ProjectCodec.decode(legacy).groups.isEmpty)
    }

    @Test func groupsFromOlderFilesGetDefaults() throws {
        let json = Data("""
        {"schemaVersion": 1, "media": [], "groups": [{"id": "\(UUID())", "name": "Alt",
          "entries": [{"id": "\(UUID())", "mediumID": "\(UUID())", "imageDuration": 4}]}]}
        """.utf8)
        let group = try #require(ProjectCodec.decode(json).groups.first)
        #expect(group.crossfade == MediaGroup.defaultCrossfade)
        #expect(group.entries.first?.layers == [])
        #expect(group.entries.first?.imageDuration == 4)
    }
}
