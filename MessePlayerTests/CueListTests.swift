import Foundation
import Testing
@testable import MessePlayer

struct CueListTests {
    /// Projekt mit je einem Cue pro Medium (Nummern 1…n), Bilder außer den genannten Videos.
    private func project(_ count: Int, videos: Set<Int> = []) -> Project {
        var project = Project()
        project.media = (0..<count).map { index in
            Medium(id: UUID(), kind: videos.contains(index) ? .video : .image, fileName: "m\(index)", displayName: "Medium \(index + 1).jpg")
        }
        project.insertCues(for: project.media.map(\.id), at: 0)
        return project
    }

    @discardableResult
    private func formGroup(_ project: inout Project, _ ids: Set<Cue.ID>) throws -> CueGroup.ID {
        let id = project.formGroup(from: ids)
        return try #require(id)
    }

    private func numbers(_ project: Project) -> [String] {
        project.cues.map(\.number)
    }

    private func ids(_ project: Project, _ indices: Int...) -> Set<Cue.ID> {
        Set(indices.map { project.cues[$0].id })
    }

    // MARK: Einfügen

    @Test func droppedMediaBecomeCuesWithDefaults() throws {
        var project = project(2, videos: [1])
        #expect(numbers(project) == ["1", "2"])
        #expect(project.cues.map(\.name) == ["Medium 1", "Medium 2"])
        #expect(project.cues.allSatisfy { $0.outputID == project.outputs.first?.id && $0.followAction == .hold })
        #expect(project.duration(of: project.cues[0], mediaLength: nil) == 5)
        #expect(project.duration(of: project.cues[1], mediaLength: 42.3) == 42.3)

        project.insertCues(for: [project.media[0].id], at: 1)
        #expect(numbers(project) == ["1", "3", "2"])
    }

    @Test func audioCuesHaveNoOutput() {
        var project = Project()
        project.media = [Medium(id: UUID(), kind: .audio, fileName: "a", displayName: "Musik.wav")]
        project.insertCues(for: [project.media[0].id], at: 0)
        #expect(project.cues[0].outputID == nil)
        project.apply(.output(project.outputs[0].id), to: [project.cues[0].id])
        #expect(project.cues[0].outputID == nil)
    }

    // MARK: Mehrfachauswahl

    @Test func editsApplyToAllSelectedCues() {
        var project = project(3)
        let selected = ids(project, 0, 2)
        let output2 = OutputDefinition.numbered(2)
        project.outputs.append(output2)
        project.apply(.followAction(.followOnEnd), to: selected)
        project.apply(.output(output2.id), to: selected)
        project.apply(.wait(2.5), to: selected)
        project.apply(.duration(8), to: selected)

        for index in [0, 2] {
            #expect(project.cues[index].followAction == .followOnEnd)
            #expect(project.cues[index].outputID == output2.id)
            #expect(project.cues[index].wait == 2.5)
            #expect(project.cues[index].stillDuration == 8)
        }
        #expect(project.cues[1].followAction == .hold)
        #expect(project.cues[1].wait == 0)
        #expect(project.cues[1].stillDuration == Cue.defaultStillDuration)
    }

    @Test func numberAndNameNeverApplyToSelection() {
        #expect(!CueEdit.number("1").appliesToSelection)
        #expect(!CueEdit.name("A").appliesToSelection)
        #expect(CueEdit.wait(1).appliesToSelection)
    }

    @Test func shorteningVideoSetsOutPoint() {
        var project = project(1, videos: [0])
        let id = project.cues[0].id
        project.apply(.duration(30), to: [id], mediaLength: { _ in 60 })
        #expect(project.cues[0].outPoint == 30)
        project.apply(.duration(90), to: [id], mediaLength: { _ in 60 })
        #expect(project.cues[0].outPoint == nil)
    }

    @Test func manualNumberIsTrimmedAndKept() {
        var project = project(2)
        project.apply(.number(" 1.5 "), to: ids(project, 1))
        #expect(numbers(project) == ["1", "1.5"])
        project.moveCues(ids(project, 1), toOffset: 0, joining: nil)
        #expect(numbers(project) == ["1.5", "1"])
    }

    // MARK: Gruppen

    @Test func formsGroupFromContiguousSelectionOnly() throws {
        var project = project(5)
        #expect(!project.canFormGroup(from: ids(project, 1, 3)))
        #expect(project.formGroup(from: ids(project, 1, 3)) == nil)

        let groupID = try formGroup(&project, ids(project, 1, 2, 3))
        let group = try #require(project.groups.first)
        #expect(group.id == groupID)
        #expect(group.mode == .loop)
        #expect(project.cueRange(of: group) == 1...3)
        #expect(project.validationIssues.isEmpty)
    }

    @Test func groupsDoNotNest() throws {
        var project = project(5)
        try formGroup(&project, ids(project, 1, 2))
        #expect(!project.canFormGroup(from: ids(project, 2, 3)))
        // Ganz enthaltene Gruppe geht in der neuen auf.
        try formGroup(&project, ids(project, 0, 1, 2, 3))
        #expect(project.groups.count == 1)
        #expect(project.cueRange(of: project.groups[0]) == 0...3)
    }

    @Test func dissolvingKeepsCues() throws {
        var project = project(3)
        let groupID = try formGroup(&project, ids(project, 0, 1))
        project.dissolveGroups(touching: [groupID])
        #expect(project.groups.isEmpty)
        #expect(project.cues.count == 3)
        try formGroup(&project, ids(project, 0, 1))
        project.dissolveGroups(touching: ids(project, 1))
        #expect(project.groups.isEmpty)
    }

    @Test func rowsShowHeaderBracketAndCollapse() throws {
        var project = project(4)
        try formGroup(&project, ids(project, 1, 2))
        let rows = project.listRows
        #expect(rows.count == 5)
        guard case .group = rows[1], case .cue(_, .member) = rows[2], case .cue(_, .last) = rows[3], case .cue(_, nil) = rows[4] else {
            Issue.record("Unerwartete Zeilen: \(rows)")
            return
        }
        project.groups[0].isCollapsed = true
        #expect(project.listRows.count == 3)
        #expect(project.cueIDs(inSelection: [project.groups[0].id]) == ids(project, 1, 2))
    }

    @Test func groupSetsFollowActionAndOutput() throws {
        var project = project(3)
        try formGroup(&project, ids(project, 0, 1))
        #expect(project.followActionIsSetByGroup(project.cues[0]))
        #expect(project.followActionIsSetByGroup(project.cues[1]))
        #expect(!project.followActionIsSetByGroup(project.cues[2]))
        project.groups[0].mode = .repeatCount(3)
        #expect(project.followActionIsSetByGroup(project.cues[0]))
        #expect(!project.followActionIsSetByGroup(project.cues[1]))

        let output2 = OutputDefinition.numbered(2)
        project.outputs.append(output2)
        project.setOutput(output2.id, forGroup: project.groups[0].id)
        #expect(project.cues.map(\.outputID) == [output2.id, output2.id, project.outputs[0].id])
    }

    @Test func groupDurationSumsWaitAndDuration() throws {
        var project = project(2, videos: [1])
        project.apply(.wait(1), to: ids(project, 0))
        try formGroup(&project, ids(project, 0, 1))
        #expect(project.duration(of: project.groups[0], mediaLength: { _ in nil }) == nil)
        #expect(project.duration(of: project.groups[0], mediaLength: { _ in 10 }) == 16)
    }

    // MARK: Verschieben und Ablegen

    @Test func dropBetweenMembersJoinsGroup() throws {
        var project = project(4)
        let groupID = try formGroup(&project, ids(project, 0, 1))
        let rows = project.listRows // Kopf, 1, 2, 3, 4
        #expect(project.dropTarget(in: rows, before: 1) == CueDropTarget(offset: 0, groupID: groupID))
        #expect(project.dropTarget(in: rows, before: 2) == CueDropTarget(offset: 1, groupID: groupID))
        #expect(project.dropTarget(in: rows, before: 3) == CueDropTarget(offset: 2, groupID: nil))
        #expect(project.dropTarget(in: rows, before: 0) == CueDropTarget(offset: 0, groupID: nil))
        #expect(project.dropTarget(in: rows, before: 5) == CueDropTarget(offset: 4, groupID: nil))

        let moved = ids(project, 3)
        let target = project.dropTarget(in: rows, before: 2, moving: moved)
        project.moveCues(moved, toOffset: target.offset, joining: target.groupID)
        #expect(numbers(project) == ["1", "4", "2", "3"])
        #expect(project.cueRange(of: project.groups[0]) == 0...2)
    }

    @Test func movingMemberOutLeavesGroupAndKeepsNumbers() throws {
        var project = project(4)
        try formGroup(&project, ids(project, 0, 1, 2))
        project.moveCues(ids(project, 1), toOffset: 4, joining: nil)
        #expect(numbers(project) == ["1", "3", "4", "2"])
        #expect(project.cueRange(of: project.groups[0]) == 0...1)
        #expect(project.validationIssues.isEmpty)
    }

    @Test func reorderingToGroupEndStaysInGroup() throws {
        var project = project(3)
        let groupID = try formGroup(&project, ids(project, 0, 1))
        let rows = project.listRows // Kopf, 1, 2, 3
        let target = project.dropTarget(in: rows, before: 3, moving: ids(project, 0))
        #expect(target == CueDropTarget(offset: 2, groupID: groupID))
        project.moveCues(ids(project, 0), toOffset: target.offset, joining: target.groupID)
        #expect(numbers(project) == ["2", "1", "3"])
        #expect(project.cueRange(of: project.groups[0]) == 0...1)
    }

    @Test func movingWholeGroupKeepsIt() throws {
        var project = project(4)
        try formGroup(&project, ids(project, 0, 1))
        project.moveCues(ids(project, 0, 1), toOffset: 4, joining: nil)
        #expect(numbers(project) == ["3", "4", "1", "2"])
        #expect(project.cueRange(of: project.groups[0]) == 2...3)
    }

    // MARK: Spalten und Zeitformat

    @Test func columnVisibilityRoundTrips() {
        var visibility = CueColumnVisibility()
        #expect(visibility.visible == CueColumn.allCases)
        visibility.toggle(.wait)
        visibility.toggle(.remaining)
        let restored = CueColumnVisibility(rawValue: visibility.rawValue)
        #expect(restored.visible == [.status, .number, .name, .output, .duration, .followAction])
        #expect(CueColumnVisibility(rawValue: "unbekannt,wait").hidden == [.wait])
    }

    @Test(arguments: [("42", "0:42.00"), ("1:05", "1:05.00"), ("0:42.3", "0:42.30")])
    func timeFieldParsesAndFormats(input: String, shown: String) throws {
        let style = TimeFormatStyle()
        #expect(style.format(try style.parseStrategy.parse(input)) == shown)
    }

    @Test func timeFieldRejectsGarbage() {
        #expect(throws: (any Error).self) { try TimeFormatStyle().parseStrategy.parse("abc") }
    }

    // MARK: Migration

    @Test func migratedV1ProjectShowsGroupsInList() throws {
        let url = try #require(Bundle(for: CueListBundleToken.self).url(forResource: "hochzeitsmesse-v1", withExtension: "json"))
        let project = try ProjectCodec.decode(Data(contentsOf: url))
        let rows = project.listRows
        let headers = rows.filter { if case .group = $0 { true } else { false } }
        #expect(headers.count == project.groups.filter { !$0.isEmpty }.count)
        #expect(rows.count == headers.count + project.cues.count)
    }
}


private final class CueListBundleToken {}
