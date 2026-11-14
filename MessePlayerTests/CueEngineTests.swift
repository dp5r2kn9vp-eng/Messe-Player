import Foundation
import Testing
@testable import MessePlayer

/// Bausteine für Test-Shows ohne Projektdatei.
enum ShowFixture {
    static let outputA1 = UUID()
    static let outputA2 = UUID()

    static func cue(_ kind: Medium.Kind, duration: TimeInterval? = 5, follow: FollowAction = .hold, output: UUID? = outputA1, wait: TimeInterval = 0) -> ShowCue {
        let medium = Medium(id: UUID(), kind: kind, fileName: "x", displayName: "x")
        return ShowCue(
            id: UUID(),
            content: .media(PlayableMedium(medium: medium, url: URL(filePath: "/tmp/x")), layers: []),
            outputID: kind == .audio ? nil : output,
            wait: wait,
            duration: duration,
            endsWithMedia: false,
            followAction: follow
        )
    }

    static func missing(follow: FollowAction = .hold) -> ShowCue {
        ShowCue(id: UUID(), content: .missing, outputID: outputA1, duration: nil, followAction: follow)
    }

    static func show(_ cues: [ShowCue], groups: [(ClosedRange<Int>, CueGroup.Mode)] = []) -> CueShow {
        CueShow(
            cues: cues,
            groups: groups.map { ShowGroup(id: UUID(), range: $0.0, mode: $0.1, crossfade: 0.5) },
            primaryOutputID: outputA1
        )
    }
}

@MainActor
struct CueEngineTests {
    let clock = VirtualClock()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: RecordingAudioOutput())
    }

    private func visible(on output: UUID = ShowFixture.outputA1) -> Cue.ID? {
        engine.state(for: output).content.frame?.cueID
    }

    /// Sichtbare Cues nach jedem Schritt von `step` Sekunden.
    private func sequence(steps: Int, every step: TimeInterval = 5) -> [Cue.ID?] {
        (0..<steps).map { _ in
            defer { clock.advance(by: step) }
            return visible()
        }
    }

    // MARK: Beispielabläufe (Konzept, Tabelle 4.3)

    @Test func holdKeepsImageUntilNextGo() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(visible() == cues[0].id)
        #expect(engine.playheadID == cues[1].id)

        clock.advance(by: 5)
        #expect(visible() == cues[0].id)
        #expect(engine.running.isEmpty)
        clock.advance(by: 100)
        #expect(visible() == cues[0].id)

        engine.go()
        #expect(visible() == cues[1].id)
    }

    @Test func videoWithHoldGoesBlack() throws {
        var video = ShowFixture.cue(.video, duration: nil)
        video.endsWithMedia = true
        engine.load(ShowFixture.show([video]))
        engine.go()
        let frame = try #require(engine.state.content.frame)
        #expect(engine.running[video.id]?.progress == nil)

        engine.mediaDidFinish(cueID: video.id, step: frame.step + 1)
        #expect(engine.state.content.frame != nil)
        engine.mediaDidFinish(cueID: video.id, step: frame.step)
        guard case .blank = engine.state.content else {
            Issue.record("Ausgang sollte schwarz sein")
            return
        }
        #expect(engine.running.isEmpty)
    }

    @Test func trimmedVideoEndsByTime() {
        let video = ShowFixture.cue(.video, duration: 3)
        engine.load(ShowFixture.show([video]))
        engine.go()
        clock.advance(by: 3)
        guard case .blank = engine.state.content else {
            Issue.record("Ausgang sollte schwarz sein")
            return
        }
    }

    @Test func slideshowAdvancesEveryFiveSecondsAndLastStays() {
        let cues = (0..<5).map { _ in ShowFixture.cue(.image, follow: .followOnEnd) }
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(sequence(steps: 7) == cues.map(\.id) + [cues[4].id, cues[4].id])
        #expect(engine.running.isEmpty)
        #expect(engine.playheadID == nil)
    }

    @Test func twoScreensStartWithOneGo() {
        let cues = [
            ShowFixture.cue(.image, follow: .continueWithNext),
            ShowFixture.cue(.video, duration: 30, output: ShowFixture.outputA2),
            ShowFixture.cue(.image),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(visible(on: ShowFixture.outputA1) == cues[0].id)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
        #expect(Set(engine.running.keys) == [cues[0].id, cues[1].id])
        // GO setzt den Abspielkopf hinter die Kette „Mit nächstem starten“.
        #expect(engine.playheadID == cues[2].id)
    }

    @Test func delayedSecondScreenAppearsAfterWait() {
        let cues = [
            ShowFixture.cue(.image, follow: .continueWithNext),
            ShowFixture.cue(.image, output: ShowFixture.outputA2, wait: 2),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(engine.running[cues[1].id]?.phase == .waiting)
        #expect(visible(on: ShowFixture.outputA2) == nil)
        clock.advance(by: 1.5)
        #expect(visible(on: ShowFixture.outputA2) == nil)
        clock.advance(by: 0.5)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
        #expect(engine.running[cues[1].id]?.phase == .running)
    }

    @Test func musicStartsWithLoopAndEndsWhileLoopContinues() {
        let music = ShowFixture.cue(.audio, duration: 12, follow: .continueWithNext)
        let loop = (0..<3).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show([music] + loop, groups: [(1...3, .loop)]))
        engine.go()
        #expect(Set(engine.running.keys) == [music.id, loop[0].id])
        #expect(engine.playheadID == nil)

        clock.advance(by: 12)
        #expect(engine.running[music.id] == nil)
        #expect(sequence(steps: 4) == [loop[2].id, loop[0].id, loop[1].id, loop[2].id])
    }

    @Test func loopGroupRepeatsUntilStopAndIgnoresMemberFollowActions() {
        let cues = (0..<6).map { _ in ShowFixture.cue(.image, follow: .hold) }
        engine.load(ShowFixture.show(cues, groups: [(2...4, .loop)]))
        engine.setPlayhead(cues[2].id)
        engine.go()
        #expect(engine.playheadID == cues[5].id)
        let loop = [cues[2].id, cues[3].id, cues[4].id]
        #expect(sequence(steps: 7) == loop + loop + [cues[2].id])

        engine.stopAll()
        #expect(engine.state.content == .idle)
        #expect(engine.running.isEmpty)
        #expect(clock.pendingCount == 0)
        #expect(engine.playheadID == cues[5].id)
    }

    // MARK: Gruppen

    @Test func repeatGroupRunsNTimesThenHolds() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image, follow: .hold), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues, groups: [(0...1, .repeatCount(2))]))
        engine.go()
        #expect(sequence(steps: 6) == [cues[0].id, cues[1].id, cues[0].id, cues[1].id, cues[1].id, cues[1].id])
        #expect(engine.running.isEmpty)
    }

    @Test func repeatGroupThenFollowsOnWithLastCuesAction() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image, follow: .followOnEnd), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues, groups: [(0...1, .repeatCount(1))]))
        engine.go()
        #expect(sequence(steps: 3) == cues.map(\.id))
    }

    @Test func goOnGroupMemberStartsAtFirstMember() {
        let cues = (0..<3).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show(cues, groups: [(0...2, .loop)]))
        engine.setPlayhead(cues[1].id)
        engine.go()
        #expect(visible() == cues[0].id)
        #expect(engine.running[cues[0].id]?.groupRun?.pass == 1)
    }

    @Test func nextCueOnSameOutputReplacesRunningLoop() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues, groups: [(0...1, .loop)]))
        engine.go()
        engine.go()
        #expect(visible() == cues[2].id)
        #expect(Set(engine.running.keys) == [cues[2].id])
        clock.advance(by: 20)
        #expect(visible() == cues[2].id)
    }

    @Test func groupUsesItsCrossfade() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues, groups: [(0...1, .loop)]))
        engine.go()
        #expect(engine.state.transition == 0.5)
    }

    // MARK: Transport

    // MARK: Nachwarten

    private func postWaitShow(_ postWait: TimeInterval, follow: FollowAction = .continueWithNext) -> [ShowCue] {
        var first = ShowFixture.cue(.image, duration: 1, follow: follow)
        first.postWait = postWait
        let cues = [first, ShowFixture.cue(.image, output: ShowFixture.outputA2), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        return cues
    }

    @Test func postWaitDelaysNextCueFromStartOfThisCue() {
        let cues = postWaitShow(2)
        engine.go()
        #expect(visible(on: ShowFixture.outputA2) == nil)
        #expect(engine.playheadID == cues[1].id)
        clock.advance(by: 1.9)
        #expect(visible(on: ShowFixture.outputA2) == nil)
        clock.advance(by: 0.1)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
        #expect(engine.playheadID == cues[2].id)
    }

    @Test(arguments: [FollowAction.hold, .followOnEnd])
    func postWaitIsIgnoredWithoutContinueWithNext(follow: FollowAction) {
        let cues = postWaitShow(2, follow: follow)
        engine.go()
        clock.advance(by: 2)
        #expect(visible(on: ShowFixture.outputA2) == (follow == .followOnEnd ? cues[1].id : nil))
        #expect(!engine.hasPendingStarts)
    }

    @Test func pauseHoldsPostWait() {
        let cues = postWaitShow(3)
        engine.go()
        clock.advance(by: 1)
        #expect(engine.togglePause())
        clock.advance(by: 50)
        #expect(visible(on: ShowFixture.outputA2) == nil)
        engine.togglePause()
        clock.advance(by: 1.9)
        #expect(visible(on: ShowFixture.outputA2) == nil)
        clock.advance(by: 0.1)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
    }

    @Test func pauseWorksWhileOnlyPostWaitRuns() {
        _ = postWaitShow(5)
        engine.go()
        clock.advance(by: 2)
        #expect(engine.running.isEmpty)
        #expect(engine.togglePause())
    }

    @Test func stopCancelsPostWait() {
        _ = postWaitShow(2)
        engine.go()
        engine.stopAll()
        #expect(!engine.hasPendingStarts)
        #expect(clock.pendingCount == 0)
    }

    @Test func pauseKeepsRemainingTime() {
        let cues = [ShowFixture.cue(.image, duration: 10, follow: .followOnEnd), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        clock.advance(by: 4)
        #expect(engine.togglePause())
        #expect(engine.state.isPaused)
        #expect(clock.pendingCount == 0)

        clock.advance(by: 100)
        #expect(visible() == cues[0].id)
        engine.togglePause()
        #expect(!engine.state.isPaused)
        #expect(engine.running[cues[0].id]?.progress?.remaining(at: clock.now) == 6)
        clock.advance(by: 5.5)
        #expect(visible() == cues[0].id)
        clock.advance(by: 0.5)
        #expect(visible() == cues[1].id)
    }

    @Test func nothingToPauseWhenNothingRuns() {
        engine.load(ShowFixture.show([ShowFixture.cue(.image)]))
        #expect(!engine.togglePause())
    }

    @Test func stopAllKeepsPlayhead() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.stopAll()
        #expect(engine.state.content == .idle)
        #expect(engine.playheadID == cues[1].id)
    }

    @Test func blackCoversAllOutputsWhileCuesRunOn() {
        let cues = [ShowFixture.cue(.image, follow: .followOnEnd), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.toggleBlack()
        #expect(engine.state(for: ShowFixture.outputA1).isBlack)
        #expect(engine.state(for: ShowFixture.outputA2).isBlack)
        clock.advance(by: 5)
        #expect(visible() == cues[1].id)
        engine.toggleBlack()
        #expect(!engine.state.isBlack)
    }

    @Test func followOnEndOnLastCueHolds() {
        let cue = ShowFixture.cue(.image, follow: .followOnEnd)
        engine.load(ShowFixture.show([cue]))
        engine.go()
        clock.advance(by: 30)
        #expect(visible() == cue.id)
        #expect(engine.running.isEmpty)
    }

    @Test func playheadMovesWithoutStarting() {
        let cues = (0..<3).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show(cues))
        #expect(engine.playheadID == cues[0].id)
        engine.movePlayhead(by: 2)
        #expect(engine.playheadID == cues[2].id)
        engine.movePlayhead(by: 5)
        #expect(engine.playheadID == cues[2].id)
        engine.movePlayhead(by: -1)
        #expect(engine.playheadID == cues[1].id)
        #expect(engine.running.isEmpty)
    }

    // MARK: Fehlendes Medium

    @Test func missingMediumOnGoReportsAndShowsNothing() {
        let cues = [ShowFixture.missing(), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(engine.missingCueID == cues[0].id)
        #expect(engine.state.content == .idle)
        #expect(engine.playheadID == cues[1].id)
        engine.go()
        #expect(engine.missingCueID == nil)
    }

    @Test func missingMediumIsSkippedInAutoFollow() {
        let cues = [ShowFixture.cue(.image, follow: .followOnEnd), ShowFixture.missing(follow: .followOnEnd), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        clock.advance(by: 5)
        #expect(visible() == cues[2].id)
        #expect(engine.missingCueID == nil)
    }

    @Test func missingMediumInChainLetsRestRun() {
        let cues = [ShowFixture.missing(follow: .continueWithNext), ShowFixture.cue(.image, output: ShowFixture.outputA2)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
        #expect(engine.missingCueID == cues[0].id)
    }

    @Test func loopWithoutPlayableMediaStops() {
        let cues = [ShowFixture.missing(), ShowFixture.missing()]
        engine.load(ShowFixture.show(cues, groups: [(0...1, .loop)]))
        engine.go()
        #expect(engine.running.isEmpty)
        #expect(engine.state.content == .idle)
    }

    // MARK: Änderungen der Liste

    @Test func deletedPlayheadMovesToFollowingCue() {
        let cues = (0..<3).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show(cues))
        engine.setPlayhead(cues[1].id)
        engine.update(ShowFixture.show([cues[0], cues[2]]))
        #expect(engine.playheadID == cues[2].id)
    }

    @Test func deletedRunningCueStops() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.update(ShowFixture.show([cues[1]]))
        #expect(engine.running.isEmpty)
        #expect(clock.pendingCount == 0)
    }
}
