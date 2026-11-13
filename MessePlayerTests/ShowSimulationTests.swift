import Foundation
import Testing
@testable import MessePlayer

/// Beispiele aus Konzept 4.3 als Zeitstrahl.
@MainActor
struct ShowSimulationTests {
    private func images(_ count: Int, follow: FollowAction = .hold) -> [ShowCue] {
        (0..<count).map { _ in ShowFixture.cue(.image, follow: follow) }
    }

    private func times(_ bar: TimelineBar?) -> [TimeInterval?] {
        [bar?.start, bar?.appear, bar?.end]
    }

    @Test func slideshowRunsWithOneGoAndLastImageStays() {
        let cues = images(5, follow: .followOnEnd)
        let timeline = ShowSimulation.run(ShowFixture.show(cues))
        #expect(timeline.goTimes == [0])
        #expect(timeline.bars.map(\.start) == [0, 5, 10, 15, 20])
        #expect(timeline.bars.map(\.end) == [5, 10, 15, 20, 25])
        #expect(timeline.bars.last?.visibleUntil == nil)
        #expect(timeline.bars.allSatisfy { !$0.holds })
    }

    @Test func continueWithNextStartsBothOutputsTogether() {
        let cues = [
            ShowFixture.cue(.image, follow: .continueWithNext),
            ShowFixture.cue(.video, duration: 8, output: ShowFixture.outputA2),
        ]
        let timeline = ShowSimulation.run(ShowFixture.show(cues))
        #expect(timeline.goTimes == [0])
        #expect(timeline.bar(for: cues[0].id)?.lane == .output(ShowFixture.outputA1))
        #expect(timeline.bar(for: cues[1].id)?.lane == .output(ShowFixture.outputA2))
        #expect(times(timeline.bar(for: cues[1].id)) == [0, 0, 8])
        #expect(timeline.bar(for: cues[1].id)?.visibleUntil == 8)
        #expect(timeline.bar(for: cues[1].id)?.holds == true)
    }

    @Test func waitDelaysSecondScreen() {
        let cues = [
            ShowFixture.cue(.image, follow: .continueWithNext),
            ShowFixture.cue(.image, output: ShowFixture.outputA2, wait: 2),
        ]
        let timeline = ShowSimulation.run(ShowFixture.show(cues))
        #expect(times(timeline.bar(for: cues[1].id)) == [0, 2, 7])
    }

    @Test func musicRunsAlongsideEndlessLoop() {
        let music = ShowFixture.cue(.audio, duration: 12, follow: .continueWithNext)
        let loop = images(3)
        let timeline = ShowSimulation.run(ShowFixture.show([music] + loop, groups: [(1...3, .loop)]))
        #expect(times(timeline.bar(for: music.id)) == [0, 0, 12])
        #expect(timeline.bar(for: music.id)?.lane == .audio)
        #expect(loop.map { timeline.bar(for: $0.id)?.start } == [0, 5, 10])
        #expect(timeline.bars.count == 4)
        #expect(timeline.loops.map(\.start) == [15])
        #expect(timeline.loops.first?.end == nil)
        #expect(timeline.loops.first?.holds == false)
    }

    @Test func loopGroupRunsOncePerBarUntilNextGoReplacesIt() {
        let cues = images(6)
        let timeline = ShowSimulation.run(ShowFixture.show(cues, groups: [(2...4, .loop)]))
        #expect(timeline.goTimes == [0, 5, 10, 25])
        #expect(cues.map { timeline.bar(for: $0.id)?.start } == [0, 5, 10, 15, 20, 25])
        #expect(timeline.bars.map(\.holds) == [true, true, false, false, false, true])
        #expect(timeline.loops.map(\.start) == [25])
        #expect(timeline.loops.first?.end == 25)
        #expect(timeline.bars.last?.visibleUntil == nil)
    }

    @Test func holdWaitsForGoAndVideoGoesBlack() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.video)]
        let timeline = ShowSimulation.run(ShowFixture.show(cues))
        #expect(timeline.goTimes == [0, 5])
        #expect(timeline.bar(for: cues[0].id)?.visibleUntil == 5)
        #expect(times(timeline.bar(for: cues[1].id)) == [5, 5, 10])
        #expect(timeline.bar(for: cues[1].id)?.visibleUntil == 10)
        #expect(timeline.bars.allSatisfy { $0.holds })
    }

    @Test func repeatGroupShowsOnePassThenRepeats() {
        let cues = images(3)
        let timeline = ShowSimulation.run(ShowFixture.show(cues, groups: [(0...1, .repeatCount(3))]))
        #expect(timeline.bars.map(\.start) == [0, 5, 30])
        #expect(timeline.loops.map { [$0.start, $0.end] } == [[10, 30]])
        #expect(timeline.loops.first?.holds == true)
        #expect(timeline.goTimes == [0, 30])
    }

    @Test func videoEndingWithMediaUsesKnownLength() {
        var video = ShowFixture.cue(.video, duration: 7, follow: .followOnEnd)
        video.endsWithMedia = true
        let image = ShowFixture.cue(.image)
        let timeline = ShowSimulation.run(ShowFixture.show([video, image]))
        #expect(timeline.bar(for: image.id)?.start == 7)
    }

    @Test func missingMediumIsSkipped() {
        let cues = [ShowFixture.cue(.image, follow: .followOnEnd), ShowFixture.missing()]
        let timeline = ShowSimulation.run(ShowFixture.show(cues))
        #expect(timeline.bars.map(\.cueID) == [cues[0].id])
    }

    // MARK: Vergleich mit der Engine

    /// Dieselben Fälle in der Engine mit virtueller Uhr (Zehntelsekunden), GO sobald nichts mehr läuft.
    @Test(arguments: ComparisonCase.allCases)
    func simulationMatchesEngine(_ example: ComparisonCase) {
        let show = example.show
        let simulated = ShowSimulation.run(show)
        let observed = EngineObservation.run(show, until: simulated.lastEvent + 1)
        for bar in simulated.bars {
            #expect(observed[bar.cueID] == [bar.start, bar.appear, bar.end], "\(example)")
        }
        #expect(Set(observed.keys) == Set(simulated.bars.map(\.cueID)), "\(example)")
    }
}

enum ComparisonCase: CaseIterable, CustomStringConvertible {
    case slideshow, continueWithNext, wait, musicToLoop, loopGroup, hold

    var description: String { "\(self)" }

    @MainActor var show: CueShow {
        let image = { (follow: FollowAction) in ShowFixture.cue(.image, follow: follow) }
        switch self {
        case .slideshow:
            return ShowFixture.show((0..<5).map { _ in image(.followOnEnd) })
        case .continueWithNext:
            return ShowFixture.show([image(.continueWithNext), ShowFixture.cue(.video, duration: 8, output: ShowFixture.outputA2)])
        case .wait:
            return ShowFixture.show([image(.continueWithNext), ShowFixture.cue(.image, output: ShowFixture.outputA2, wait: 2)])
        case .musicToLoop:
            let music = ShowFixture.cue(.audio, duration: 12, follow: .continueWithNext)
            return ShowFixture.show([music, image(.hold), image(.hold), image(.hold)], groups: [(1...3, .loop)])
        case .loopGroup:
            return ShowFixture.show((0..<4).map { _ in image(.hold) } + [image(.followOnEnd)], groups: [(1...3, .loop)])
        case .hold:
            return ShowFixture.show([image(.hold), ShowFixture.cue(.video), image(.hold)])
        }
    }
}

/// Beobachtet die echte Engine im Takt von 0,1 s: erster Start, Erscheinen und Ende je Cue.
@MainActor
enum EngineObservation {
    static func run(_ show: CueShow, until end: TimeInterval) -> [Cue.ID: [TimeInterval?]] {
        let clock = VirtualClock()
        let engine = CueEngine(scheduler: clock, now: { clock.now }, audio: RecordingAudioOutput())
        engine.load(show)
        var seen: [Cue.ID: [TimeInterval?]] = [:]
        var loopStarted: Set<Cue.ID> = []
        let tick = 0.1
        for index in 0...Int((end / tick).rounded()) {
            let time = Double(index) * tick
            if engine.running.isEmpty || loopsOnly(engine, show) {
                if engine.playheadID != nil { engine.go() }
            }
            for running in engine.running.values {
                if (running.groupRun?.pass ?? 1) > 1 { loopStarted.insert(running.cueID) }
                guard !loopStarted.contains(running.cueID) else { continue }
                if seen[running.cueID] == nil { seen[running.cueID] = [time, nil, nil] }
                if running.phase == .running, seen[running.cueID]?[1] == nil { seen[running.cueID]?[1] = time }
            }
            for (id, times) in seen where times[2] == nil && engine.running[id] == nil && !loopStarted.contains(id) {
                seen[id]?[2] = time
            }
            for (id, times) in seen where times[2] == nil && engine.running[id]?.groupRun.map({ $0.pass > 1 }) == true {
                seen[id]?[2] = time
            }
            clock.advance(by: tick)
        }
        return seen.mapValues { $0.map { $0.map { ($0 * 10).rounded() / 10 } } }
    }

    private static func loopsOnly(_ engine: CueEngine, _ show: CueShow) -> Bool {
        engine.running.values.allSatisfy { running in
            guard let run = running.groupRun, run.pass > 1 else { return false }
            return show.groups.first { $0.id == run.groupID }?.mode == .loop
        }
    }
}

@MainActor
struct TimelineLayoutTests {
    @Test func lanesFollowOutputsThenAudioAndOverlapsGetOwnRows() {
        let outputs = [OutputDefinition(id: ShowFixture.outputA1, name: "Ausgang 1"), OutputDefinition(id: ShowFixture.outputA2, name: "Ausgang 2")]
        let music = [ShowFixture.cue(.audio, duration: 10, follow: .continueWithNext), ShowFixture.cue(.audio, duration: 4, follow: .continueWithNext)]
        var show = ShowFixture.show(music + [ShowFixture.cue(.image)])
        show.outputs = outputs
        let layout = TimelineLayout(timeline: ShowSimulation.run(show), outputs: outputs)
        #expect(layout.lanes.map(\.lane) == [.output(ShowFixture.outputA1), .output(ShowFixture.outputA2), .audio])
        #expect(layout.lanes.map(\.rows.count) == [1, 1, 2])
        #expect(layout.lanes[1].rows == [[]])
        #expect(layout.length == TimelineLayout.minimumLength)
    }

    @Test func listChangeChangesTimeline() {
        var cues = (0..<2).map { _ in ShowFixture.cue(.image, follow: .followOnEnd) }
        let before = ShowSimulation.run(ShowFixture.show(cues))
        cues[0].duration = 8
        let after = ShowSimulation.run(ShowFixture.show(cues))
        #expect(before.bar(for: cues[1].id)?.start == 5)
        #expect(after.bar(for: cues[1].id)?.start == 8)
    }
}
