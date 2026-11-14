import Foundation
import Testing
@testable import MessePlayer

/// Zufallsgenerator mit festem Startwert (SplitMix64), damit Zufallstests reproduzierbar sind.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct GroupOrderTests {
    let ids = (0..<4).map { _ in UUID() }

    @Test func listOrderWithoutShuffle() {
        #expect(GroupOrder.pass(of: ids, isShuffled: false, shuffle: { $0.reversed() }) == ids)
        #expect(GroupOrder.pass(of: ids, isShuffled: false, first: ids[2], shuffle: { $0 }) == [ids[2], ids[3]])
    }

    @Test func shuffledPassKeepsChosenFirstCue() {
        let order = GroupOrder.pass(of: ids, isShuffled: true, first: ids[2], shuffle: { $0.reversed() })
        #expect(order == [ids[2], ids[3], ids[1], ids[0]])
    }

    @Test func shuffledPassDoesNotRepeatPreviousLastCue() {
        let order = GroupOrder.pass(of: ids, isShuffled: true, previousLast: ids[0], shuffle: { $0 })
        #expect(order.first != ids[0])
        #expect(Set(order) == Set(ids))
    }

    @Test func singleCueGroupStaysValid() {
        #expect(GroupOrder.pass(of: [ids[0]], isShuffled: true, previousLast: ids[0], shuffle: { $0 }) == [ids[0]])
    }
}

@MainActor
struct GroupShuffleEngineTests {
    let clock = VirtualClock()
    let engine: CueEngine

    init() {
        let clock = clock
        var generator = SeededGenerator(seed: 79)
        engine = CueEngine(
            scheduler: clock,
            now: { clock.now },
            audio: RecordingAudioOutput(),
            shuffle: { $0.shuffled(using: &generator) }
        )
    }

    private func shuffledShow(_ cues: [ShowCue], group range: ClosedRange<Int>, mode: CueGroup.Mode = .loop) -> CueShow {
        var show = ShowFixture.show(cues, groups: [(range, mode)])
        show.groups[0].isShuffled = true
        return show
    }

    /// Sichtbare Cues nach jedem 5-s-Schritt.
    private func sequence(steps: Int) -> [Cue.ID?] {
        (0..<steps).map { _ in
            defer { clock.advance(by: 5) }
            return engine.state.content.frame?.cueID
        }
    }

    @Test func everyPassShowsEachCueOnceWithoutDirectRepeat() throws {
        let cues = (0..<4).map { _ in ShowFixture.cue(.image) }
        engine.load(shuffledShow(cues, group: 0...3))
        engine.go()
        let seen = try sequence(steps: 40).map { try #require($0) }
        for pass in stride(from: 0, to: seen.count, by: 4) {
            #expect(Set(seen[pass..<pass + 4]) == Set(cues.map(\.id)))
        }
        for (current, next) in zip(seen, seen.dropFirst()) {
            #expect(current != next)
        }
        #expect(seen != Array(repeating: cues.map(\.id), count: 10).flatMap(\.self))
    }

    @Test func repeatCountShuffledThenFollowsOnWithLastListCue() {
        var cues = (0..<3).map { _ in ShowFixture.cue(.image) }
        cues[2] = ShowFixture.cue(.image, follow: .followOnEnd)
        let after = ShowFixture.cue(.image)
        engine.load(shuffledShow(cues + [after], group: 0...2, mode: .repeatCount(2)))
        engine.go()
        let seen = sequence(steps: 7)
        #expect(Set(seen.prefix(3).compactMap(\.self)) == Set(cues.map(\.id)))
        #expect(Set(seen[3..<6].compactMap(\.self)) == Set(cues.map(\.id)))
        #expect(seen[6] == after.id)
    }

    @Test func doubleClickStartsShuffledPassWithThatCue() {
        let cues = (0..<4).map { _ in ShowFixture.cue(.image) }
        engine.load(shuffledShow(cues, group: 0...3))
        engine.start(cues[2].id)
        #expect(engine.state.content.frame?.cueID == cues[2].id)
        #expect(engine.running[cues[2].id]?.groupRun?.order.count == 4)
    }
}
