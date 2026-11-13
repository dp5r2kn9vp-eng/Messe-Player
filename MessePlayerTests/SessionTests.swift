import Foundation
import Testing
@testable import MessePlayer

@MainActor
struct SessionTests {
    let package = URL(filePath: "/tmp/Messe.klangshow")

    private func document() -> ProjectDocument {
        var document = ProjectDocument()
        document.project.media = ["A", "B"].map { Medium(id: UUID(), kind: .image, fileName: "\($0).png", displayName: $0) }
        let groupID = document.project.addGroup()
        document.project.addEntries(for: document.project.media.map(\.id), toGroup: groupID)
        return document
    }

    @Test func loopWithBlackSurvivesRestart() {
        let document = document()
        let before = OutputController(scheduler: ManualScheduler())
        let group = document.project.legacyGroups[0]
        before.startLoop(document.playlist(for: group, in: package), at: group.entries[1].id)
        before.toggleBlack()

        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        SessionStore.save(before.snapshot(projectPath: package.path), to: defaults)
        let after = OutputController(scheduler: ManualScheduler())
        after.restore(SessionStore.load(from: defaults)!, from: document, packageURL: package)

        #expect(after.playingGroupID == group.id)
        #expect(after.isLive(entry: group.entries[1].id))
        #expect(after.state.isBlack)
    }

    @Test func singleSurvivesRestartAndMissingMediumStaysIdle() {
        let document = document()
        let output = OutputController(scheduler: ManualScheduler())
        output.restore(SessionSnapshot(projectPath: package.path, mode: .single(document.project.media[0].id)), from: document, packageURL: package)
        #expect(output.isLive(document.project.media[0]))

        let fresh = OutputController(scheduler: ManualScheduler())
        fresh.restore(SessionSnapshot(projectPath: package.path, mode: .single(UUID())), from: document, packageURL: package)
        #expect(fresh.state.content == .idle)
    }
}

@MainActor
struct PauseTests {
    @Test func pauseFreezesImageAndResumesWithRemainingTime() throws {
        let scheduler = ManualScheduler()
        var now = Date(timeIntervalSince1970: 0)
        let output = OutputController(scheduler: scheduler, videoDuration: { _ in nil }, now: { now })
        let medium = Medium(id: UUID(), kind: .image, fileName: "x", displayName: "x")
        let item = LoopItem(entryID: UUID(), item: PlayableMedium(medium: medium, url: URL(filePath: "/tmp/x")), imageDuration: 10)
        output.startLoop(LoopPlaylist(groupID: UUID(), crossfade: 0, items: [item, item]))

        now += 4
        #expect(output.togglePause())
        #expect(output.state.isPaused)
        #expect(scheduler.delays.isEmpty)

        now += 100
        output.togglePause()
        #expect(!output.state.isPaused)
        #expect(scheduler.delays == [.seconds(6)])
        #expect(output.stepProgress?.startedAt == Date(timeIntervalSince1970: 100))
    }

    @Test func nothingToPauseWhenIdle() {
        #expect(!OutputController(scheduler: ManualScheduler()).togglePause())
    }
}
