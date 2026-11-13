import Foundation
import Testing
@testable import MessePlayer

/// Zeitgeber, der nur auf Kommando weiterschaltet.
final class ManualScheduler: StepScheduler {
    private var pending: [(id: Int, delay: Duration, action: () -> Void)] = []
    private var nextID = 0

    var delays: [Duration] { pending.map(\.delay) }

    func schedule(after delay: Duration, _ action: @escaping () -> Void) -> Cancellation {
        nextID += 1
        let id = nextID
        pending.append((id, delay, action))
        return Cancellation { [weak self] in self?.pending.removeAll { $0.id == id } }
    }

    func fire() {
        guard !pending.isEmpty else { return }
        pending.removeFirst().action()
    }
}

@MainActor
struct LoopEngineTests {
    let scheduler = ManualScheduler()
    let output: OutputController

    static let start = Date(timeIntervalSince1970: 1_000)

    init() {
        output = OutputController(scheduler: scheduler, videoDuration: { _ in 42 }, now: { Self.start })
    }

    private func item(_ kind: Medium.Kind, duration: TimeInterval = 5) -> LoopItem {
        let medium = Medium(id: UUID(), kind: kind, fileName: "x", displayName: "x")
        return LoopItem(entryID: UUID(), item: PlayableMedium(medium: medium, url: URL(filePath: "/tmp/x")), imageDuration: duration)
    }

    private func playlist(_ items: [LoopItem]) -> LoopPlaylist {
        LoopPlaylist(groupID: UUID(), crossfade: 0.5, items: items)
    }

    private var frame: LoopFrame? {
        if case .loop(let frame) = output.state.content { frame } else { nil }
    }

    @Test func imagesFollowTheirDurationsAndWrapAround() {
        let items = [item(.image, duration: 5), item(.image, duration: 3)]
        output.startLoop(playlist(items))
        #expect(frame?.entryID == items[0].entryID)
        #expect(scheduler.delays == [.seconds(5)])

        scheduler.fire()
        #expect(frame?.entryID == items[1].entryID)
        #expect(scheduler.delays == [.seconds(3)])

        scheduler.fire()
        #expect(frame?.entryID == items[0].entryID)
    }

    @Test func videoPlaysToEndThenOneSecondBlack() throws {
        let items = [item(.video), item(.image)]
        output.startLoop(playlist(items))
        #expect(scheduler.delays.isEmpty)

        output.mediaDidFinish(step: try #require(frame).step)
        #expect(frame?.isGap == true)
        #expect(scheduler.delays == [OutputController.videoGap])

        scheduler.fire()
        #expect(frame?.entryID == items[1].entryID)
        #expect(frame?.isGap == false)
    }

    @Test func singleVideoLoopRestartsAsNewStep() throws {
        output.startLoop(playlist([item(.video)]))
        let first = try #require(frame).step
        output.mediaDidFinish(step: first)
        scheduler.fire()
        #expect(try #require(frame).step != first)
    }

    @Test func staleFinishMessagesAreIgnored() throws {
        let items = [item(.image), item(.image)]
        output.startLoop(playlist(items))
        let first = try #require(frame).step
        scheduler.fire()
        output.mediaDidFinish(step: first)
        #expect(frame?.entryID == items[1].entryID)
    }

    @Test func brokenImageIsSkipped() throws {
        let items = [item(.image), item(.image)]
        output.startLoop(playlist(items))
        output.mediaDidFinish(step: try #require(frame).step)
        #expect(frame?.entryID == items[1].entryID)
        #expect(scheduler.delays.count == 1)
    }

    @Test func blackKeepsLoopRunningUnderneath() {
        let items = [item(.image), item(.image)]
        output.startLoop(playlist(items))
        output.toggleBlack()
        scheduler.fire()
        #expect(output.state.isBlack)
        #expect(frame?.entryID == items[1].entryID)
    }

    @Test func singleDisplayStopsLoopAndRestartResumes() {
        let items = [item(.image), item(.image)]
        let list = playlist(items)
        output.startLoop(list)
        output.showSingle(items[1].item)
        #expect(scheduler.delays.isEmpty)
        #expect(output.playingGroupID == nil)

        output.startLoop(list, at: items[1].entryID)
        #expect(frame?.entryID == items[1].entryID)
        #expect(output.playingGroupID == list.groupID)
    }

    @Test func emptyGroupShowsIdle() {
        output.startLoop(playlist([]))
        #expect(output.state.content == .idle)
    }

    @Test func updatingRunningLoopKeepsCurrentEntry() {
        let a = item(.image), b = item(.image), c = item(.image)
        let list = playlist([a, b])
        output.startLoop(list)
        scheduler.fire()
        output.updateLoop(LoopPlaylist(groupID: list.groupID, crossfade: 0, items: [c, b, a]))
        #expect(frame?.entryID == b.entryID)
        #expect(output.upcoming == a.item)
        #expect(output.state.transition == 0)
    }

    @Test func imageStepReportsItsDuration() {
        output.startLoop(playlist([item(.image, duration: 7)]))
        #expect(output.stepProgress == StepProgress(startedAt: Self.start, duration: 7))
    }

    @Test func videoStepReportsFileDurationAndGapHasNone() async throws {
        output.startLoop(playlist([item(.video), item(.image)]))
        try await Task.sleep(for: .milliseconds(50))
        #expect(output.stepProgress?.duration == 42)

        output.mediaDidFinish(step: try #require(frame).step)
        #expect(output.stepProgress == nil)
    }

    @Test func stoppingClearsProgress() {
        output.startLoop(playlist([item(.image)]))
        output.stop()
        #expect(output.stepProgress == nil)
    }
}
