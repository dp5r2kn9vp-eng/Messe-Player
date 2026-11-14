import Foundation
import Testing
@testable import MessePlayer

@MainActor
struct SessionTests {
    let package = URL(filePath: "/tmp/Messe.klangshow")

    private func document() -> ProjectDocument {
        var document = documentWithCues(["A", "B", "C"].map { Medium(id: UUID(), kind: .image, fileName: "\($0).png", displayName: $0) })
        document.project.formGroup(from: Set(document.project.cues.prefix(2).map(\.id)))
        return document
    }

    @Test func loopWithBlackAndPlayheadSurvivesRestart() throws {
        let document = document()
        let cues = document.project.cues
        let clock = VirtualClock()
        let before = CueEngine(scheduler: clock, now: { clock.now })
        before.load(document.show(in: package))
        before.go()
        clock.advance(by: 5)
        before.toggleBlack()

        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        SessionStore.save(before.snapshot(projectPath: package.path), to: defaults)
        let snapshot = try #require(SessionStore.load(from: defaults))
        #expect(snapshot.visibleCueIDs == [cues[1].id])

        let after = CueEngine(scheduler: VirtualClock())
        after.load(document.show(in: package))
        after.restore(snapshot)
        #expect(after.state.content.frame?.cueID == cues[1].id)
        #expect(after.running[cues[1].id]?.groupRun != nil)
        #expect(after.playheadID == cues[2].id)
        #expect(after.state.isBlack)
    }

    @Test func missingCueStaysIdle() {
        let engine = CueEngine(scheduler: VirtualClock())
        engine.load(document().show(in: package))
        engine.restore(SessionSnapshot(projectPath: package.path, visibleCueIDs: [UUID()]))
        #expect(engine.state.content == .idle)
    }

    @Test func oldSnapshotFormatIsIgnored() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        defaults.set(Data(#"{"projectPath":"/tmp/x","mode":{"loop":{"_0":"\#(UUID())"}},"isBlack":true}"#.utf8), forKey: "session")
        let snapshot = try #require(SessionStore.load(from: defaults))
        #expect(snapshot.projectPath == "/tmp/x")
        #expect(snapshot.visibleCueIDs.isEmpty)
        #expect(snapshot.isBlack)
    }
}

struct LaunchTests {
    @Test func cleanExitStartsWithWelcome() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        #expect(!SessionStore.beginRun(in: defaults))
        SessionStore.endRun(in: defaults)
        #expect(!SessionStore.beginRun(in: defaults))
    }

    @Test func crashRestoresLastProject() throws {
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        _ = SessionStore.beginRun(in: defaults)
        #expect(SessionStore.beginRun(in: defaults))
    }
}
