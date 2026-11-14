import Foundation
import Testing
@testable import MessePlayer

/// Steuer-Cue für Test-Shows.
extension ShowFixture {
    static func action(_ action: CueAction, follow: FollowAction = .hold) -> ShowCue {
        var cue = ShowCue(id: UUID(), content: .control, duration: action.duration, followAction: follow)
        cue.action = action
        return cue
    }
}

@MainActor
struct ActionCueEngineTests {
    let clock = VirtualClock()
    let audio = RecordingAudioOutput()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: audio)
    }

    private func frame(on output: UUID = ShowFixture.outputA1) -> CueFrame? {
        engine.state(for: output).content.frame
    }

    @Test func fadeLowersRunningMusic() {
        let music = ShowFixture.cue(.audio, duration: 60)
        let fade = ShowFixture.action(.fade(FadeAction(targetCueID: music.id, volume: 0.3, duration: 3)))
        engine.load(ShowFixture.show([music, fade]))
        engine.go()
        clock.advance(by: 10)
        engine.go()
        let level = audio.playing[music.id]?.playback.levelFade
        #expect(level?.volume == 0.3 && level?.duration == 3)
        #expect(engine.running[fade.id]?.progress?.duration == 3)
        clock.advance(by: 3)
        #expect(engine.running[fade.id] == nil)
        #expect(audio.playing[music.id] != nil)
    }

    @Test func fadeWithStopEndsTargetAfterFade() {
        let music = ShowFixture.cue(.audio, duration: 60)
        let fade = ShowFixture.action(.fade(FadeAction(targetCueID: music.id, volume: 0, duration: 2, stopsTarget: true)))
        engine.load(ShowFixture.show([music, fade]))
        engine.go()
        engine.go()
        #expect(audio.playing[music.id] != nil)
        clock.advance(by: 2)
        #expect(audio.playing[music.id] == nil)
        #expect(engine.running[music.id] == nil)
    }

    @Test func fadeOpacityReachesHeldImageAndKeepsVolume() {
        let image = ShowFixture.cue(.image, duration: 1)
        let first = ShowFixture.action(.fade(FadeAction(targetCueID: image.id, volume: 0.5, duration: 1)))
        let second = ShowFixture.action(.fade(FadeAction(targetCueID: image.id, volume: nil, opacity: 0, duration: 2)))
        engine.load(ShowFixture.show([image, first, second]))
        engine.go()
        clock.advance(by: 5)
        #expect(engine.running[image.id] == nil)
        engine.go()
        engine.go()
        #expect(frame()?.playback.levelFade?.opacity == 0)
        #expect(frame()?.playback.levelFade?.volume == 0.5)
    }

    @Test func stopCueBlanksOutputWithFade() {
        let video = ShowFixture.cue(.video, duration: 30, output: ShowFixture.outputA2)
        let stop = ShowFixture.action(.stop(StopAction(target: .output(ShowFixture.outputA2), fadeOut: 2)))
        engine.load(ShowFixture.show([video, stop]))
        engine.go()
        engine.go()
        let state = engine.state(for: ShowFixture.outputA2)
        #expect(state.content.frame == nil)
        #expect(state.transition == 2)
        #expect(engine.running[video.id] == nil)
    }

    @Test func stopCueFadesAudioAndSkipsTargetFollowAction() {
        let music = ShowFixture.cue(.audio, duration: 60, follow: .followOnEnd)
        let stop = ShowFixture.action(.stop(StopAction(target: .cue(music.id), fadeOut: 1.5)))
        let after = ShowFixture.cue(.image)
        engine.load(ShowFixture.show([music, stop, after]))
        engine.go()
        engine.go()
        #expect(audio.calls.contains(.stop(music.id, fadeOut: 1.5)))
        clock.advance(by: 100)
        #expect(frame() == nil)
    }

    @Test func inactiveTargetIsSkippedWithNotice() {
        let music = ShowFixture.cue(.audio, duration: 60)
        let fade = ShowFixture.action(.fade(FadeAction(targetCueID: music.id)), follow: .followOnEnd)
        let after = ShowFixture.cue(.image)
        engine.load(ShowFixture.show([music, fade, after]))
        engine.setPlayhead(fade.id)
        engine.go()
        #expect(engine.inactiveTargetCueID == fade.id)
        #expect(frame()?.cueID == after.id)
        engine.go()
        #expect(engine.inactiveTargetCueID == nil)
    }

    @Test func pauseDuringFadeKeepsRemainingTime() {
        let music = ShowFixture.cue(.audio, duration: 60)
        let fade = ShowFixture.action(.fade(FadeAction(targetCueID: music.id, duration: 4)), follow: .followOnEnd)
        let after = ShowFixture.cue(.image)
        engine.load(ShowFixture.show([music, fade, after]))
        engine.go()
        engine.go()
        clock.advance(by: 1)
        engine.togglePause()
        clock.advance(by: 30)
        engine.togglePause()
        clock.advance(by: 2.9)
        #expect(frame() == nil)
        clock.advance(by: 0.1)
        #expect(frame()?.cueID == after.id)
    }

    @Test func restartingTargetClearsFade() {
        let music = ShowFixture.cue(.audio, duration: 60)
        let fade = ShowFixture.action(.fade(FadeAction(targetCueID: music.id)))
        engine.load(ShowFixture.show([music, fade]))
        engine.go()
        engine.go()
        engine.start(music.id)
        #expect(engine.levels[music.id] == nil)
        #expect(audio.playing[music.id]?.playback.levelFade == nil)
    }
}

struct ActionCueModelTests {
    @Test func schemaStaysTwoWithoutActionCues() throws {
        var project = Project()
        project.cues = [Cue(number: "1")]
        #expect(try ProjectCodec.schemaVersion(of: ProjectCodec.encode(project)) == 2)
        var fade = Cue(number: "2")
        fade.action = .fade(FadeAction(targetCueID: project.cues[0].id, volume: 0.4, opacity: 0, duration: 2, stopsTarget: true))
        var stop = Cue(number: "3")
        stop.action = .stop(StopAction(target: .output(project.outputs[0].id), fadeOut: 1))
        project.cues += [fade, stop]
        let data = try ProjectCodec.encode(project)
        #expect(try ProjectCodec.schemaVersion(of: data) == 3)
        #expect(try ProjectCodec.decode(data) == project)
    }

    @Test func deletedTargetIsReported() {
        var project = Project()
        let target = Cue(number: "1")
        var fade = Cue(number: "2")
        fade.action = .fade(FadeAction(targetCueID: target.id))
        project.cues = [target, fade]
        #expect(!project.hasMissingTarget(fade))
        project.cues.removeFirst()
        #expect(project.hasMissingTarget(fade))
        #expect(!project.hasMissingTarget(target))
    }

    @Test func insertedActionCueGetsNextNumberAndDuration() throws {
        var project = Project()
        project.cues = [Cue(number: "4")]
        let id = project.insertActionCue(.stop(StopAction(fadeOut: 2)), at: 1)
        let cue = try #require(project.cue(withID: id))
        #expect(cue.number == "5")
        #expect(project.duration(of: cue, mediaLength: nil) == 2)
        #expect(project.hasMissingTarget(cue))
    }

    @Test func actionEditOnlyChangesActionCues() {
        var project = Project()
        project.cues = [Cue(number: "1")]
        project.apply(.action(.stop(StopAction())), to: [project.cues[0].id])
        #expect(project.cues[0].action == nil)
    }

    @Test func volumeRampValueIsLinear() {
        let ramp = VolumeRamp(start: 10, duration: 4, from: 1, to: 0)
        #expect(ramp.value(at: 9) == 1)
        #expect(ramp.value(at: 12) == 0.5)
        #expect(ramp.value(at: 20) == 0)
    }

    @Test func newFadeStartsFromCurrentVolume() throws {
        var old = PlaybackSettings()
        old.audio.volume = 0.8
        var new = old
        new.levelFade = LevelFade(id: 1, volume: 0.2, duration: 2)
        let ramp = try #require(old.adjustment(changingTo: new, at: 5, current: nil))
        #expect(ramp == VolumeRamp(start: 5, duration: 2, from: 0.8, to: 0.2))
        #expect(new.adjustment(changingTo: new, at: 6, current: ramp) == ramp)
    }
}
