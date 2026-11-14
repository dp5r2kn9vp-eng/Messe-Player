import Foundation
import Testing
@testable import MessePlayer

struct CueModelTests {
    private let image = Medium(id: UUID(), kind: .image, fileName: "a.png", displayName: "A")
    private let video = Medium(id: UUID(), kind: .video, fileName: "b.mov", displayName: "B")

    private func project(cueCount: Int = 4) -> Project {
        var project = Project()
        project.media = [image, video]
        project.cues = (1...cueCount).map { Cue(number: String($0), mediumID: image.id, outputID: project.outputs.first?.id) }
        return project
    }

    // MARK: Codable

    @Test func roundTripKeepsEveryField() throws {
        var project = project()
        project.outputs.append(.numbered(2))
        var cue = project.cues[0]
        cue.name = "Intro"
        cue.wait = 1.5
        cue.inPoint = 2
        cue.outPoint = 9.25
        cue.stillDuration = 7
        cue.followAction = .continueWithNext
        cue.postWait = 2.5
        cue.schedule = CueSchedule(minuteOfDay: 840, weekdays: [2, 3])
        cue.volume = 0.4
        cue.fadeIn = 0.5
        cue.fadeOut = 1
        cue.layers = [.text("Hallo"), .logo()]
        cue.notes = "Licht beachten"
        cue.color = .white
        project.cues[0] = cue
        var group = CueGroup(name: "Loop", firstCueID: project.cues[1].id, lastCueID: project.cues[3].id)
        group.mode = .repeatCount(3)
        group.crossfade = 2
        group.isCollapsed = true
        group.isShuffled = true
        project.groups = [group]

        #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)
    }

    @Test func missingFieldsGetDefaults() throws {
        let cueID = UUID()
        let json = Data("""
        {"schemaVersion": 2, "cues": [{"id": "\(cueID)", "number": "1"}],
         "groups": [{"id": "\(UUID())", "name": "G", "firstCueID": "\(cueID)", "lastCueID": "\(cueID)"}]}
        """.utf8)
        let project = try ProjectCodec.decode(json)
        let cue = try #require(project.cues.first)
        #expect(cue == Cue(id: cueID, number: "1"))
        #expect(cue.stillDuration == 5 && cue.followAction == .hold && cue.volume == 1)
        let group = try #require(project.groups.first)
        #expect(group.mode == .loop && group.crossfade == CueGroup.defaultCrossfade && !group.isCollapsed && !group.isShuffled)
        #expect(project.outputs.map(\.name) == ["Ausgang 1"])
        #expect(project.media.isEmpty)
    }

    @Test func valuesAreClamped() {
        var cue = Cue(number: "1")
        cue.volume = 2
        cue.stillDuration = 0
        #expect(cue.volume == 1)
        #expect(cue.stillDuration == Cue.stillDurationRange.lowerBound)
        var group = CueGroup.empty(name: "G")
        group.mode = .repeatCount(500)
        group.crossfade = 9
        #expect(group.mode == .repeatCount(99))
        #expect(group.crossfade == 5)
    }

    // MARK: Dauer

    @Test func durationIsDerivedFromKindAndTrim() {
        let project = project()
        var still = Cue(number: "1", mediumID: image.id)
        still.stillDuration = 7
        var clip = Cue(number: "2", mediumID: video.id)
        #expect(project.duration(of: still, mediaLength: 60) == 7)
        #expect(project.duration(of: clip, mediaLength: 60) == 60)
        #expect(project.duration(of: clip, mediaLength: nil) == nil)
        clip.inPoint = 10
        #expect(project.duration(of: clip, mediaLength: 60) == 50)
        clip.outPoint = 25
        #expect(project.duration(of: clip, mediaLength: nil) == 15)
        clip.inPoint = 30
        #expect(project.duration(of: clip, mediaLength: 60) == 0)
        #expect(project.duration(of: Cue(number: "3"), mediaLength: nil) == 0)
    }

    // MARK: Validierung

    @Test func validProjectHasNoIssues() {
        var project = project()
        project.groups = [
            CueGroup(name: "A", firstCueID: project.cues[0].id, lastCueID: project.cues[1].id),
            CueGroup(name: "B", firstCueID: project.cues[2].id, lastCueID: project.cues[3].id),
            .empty(name: "C"),
        ]
        #expect(project.validationIssues.isEmpty)
        #expect(project.group(containing: project.cues[3].id)?.name == "B")
    }

    @Test func detectsBrokenGroupsAndMissingOutputs() {
        var project = project()
        let missing = CueGroup(name: "Fehlt", firstCueID: UUID(), lastCueID: project.cues[0].id)
        let reversed = CueGroup(name: "Verkehrt", firstCueID: project.cues[3].id, lastCueID: project.cues[2].id)
        let first = CueGroup(name: "A", firstCueID: project.cues[0].id, lastCueID: project.cues[2].id)
        let overlapping = CueGroup(name: "B", firstCueID: project.cues[2].id, lastCueID: project.cues[3].id)
        project.groups = [missing, reversed, first, overlapping]
        project.cues[1].outputID = UUID()

        #expect(project.validationIssues == [
            .groupBoundsMissing(missing.id),
            .groupReversed(reversed.id),
            .groupsOverlap(first.id, overlapping.id),
            .outputMissing(project.cues[1].id),
        ])
    }

    // MARK: Mutationen

    @Test func removingCuesMovesGroupBounds() {
        var project = project()
        project.groups = [CueGroup(name: "A", firstCueID: project.cues[0].id, lastCueID: project.cues[2].id)]
        let ids = project.cues.map(\.id)
        project.removeCues([ids[0], ids[2]])
        #expect(project.cueRange(of: project.groups[0]) == 0...0)
        #expect(project.groups[0].firstCueID == ids[1])
        project.removeCues([ids[1]])
        #expect(project.groups[0].isEmpty)
        #expect(project.validationIssues.isEmpty)
    }

    @Test func nextCueNumberFollowsHighestNumber() {
        var project = project(cueCount: 2)
        #expect(project.nextCueNumber() == "3")
        project.cues[0].number = "7.5"
        project.cues[1].number = "Intro"
        #expect(project.nextCueNumber() == "8")
        #expect(Project().nextCueNumber() == "1")
    }
}
