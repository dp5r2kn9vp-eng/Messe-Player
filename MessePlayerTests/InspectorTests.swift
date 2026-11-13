import Foundation
import Testing
@testable import MessePlayer

struct AudioLevelTests {
    @Test func volumeIsClampedAndMuteSilences() {
        var cue = Cue(number: "1")
        #expect(cue.volume == 1)
        cue.volume = 1.4
        #expect(cue.volume == 1)
        cue.volume = -0.2
        #expect(cue.volume == 0)
        cue.volume = 0.4
        cue.isMuted = true
        #expect(cue.audioLevel.target == 0)
        #expect(AudioLevel(volume: 3).target == 1)
    }

    @Test func fadesAreClamped() {
        var cue = Cue(number: "1")
        cue.fadeIn = -1
        cue.fadeOut = 500
        #expect(cue.fadeIn == 0)
        #expect(cue.fadeOut == Cue.fadeRange.upperBound)
    }

    @Test func rampsAreLinearFromStartAndBeforeEnd() {
        let level = AudioLevel(volume: 0.4, fadeIn: 1, fadeOut: 2)
        #expect(level.ramps(length: 10) == [
            VolumeRamp(start: 0, duration: 1, from: 0, to: 0.4),
            VolumeRamp(start: 8, duration: 2, from: 0.4, to: 0),
        ])
        #expect(level.ramps(from: 3, length: 10).map(\.start) == [3, 11])
        #expect(AudioLevel().ramps(length: 10).isEmpty)
    }

    @Test func overlappingFadesShrinkProportionally() {
        let level = AudioLevel(volume: 1, fadeIn: 3, fadeOut: 1)
        let fades = level.fades(length: 2)
        #expect(fades.in == 1.5)
        #expect(fades.out == 0.5)
    }

    @Test func unknownLengthHasNoFadeOut() {
        let level = AudioLevel(volume: 1, fadeIn: 1, fadeOut: 2)
        #expect(level.ramps(length: nil) == [VolumeRamp(start: 0, duration: 1, from: 0, to: 1)])
        #expect(level.volume(at: 100, length: nil) == 1)
    }

    @Test func volumeFollowsRamps() {
        let level = AudioLevel(volume: 0.8, fadeIn: 2, fadeOut: 4)
        #expect(level.volume(at: 0, length: 10) == 0)
        #expect(level.volume(at: 1, length: 10) == 0.4)
        #expect(level.volume(at: 5, length: 10) == 0.8)
        #expect(abs(level.volume(at: 8, length: 10) - 0.4) < 1e-9)
        #expect(level.volume(at: 10, length: 10) == 0)
        #expect(level.volume(at: 12, length: 10) == 0)
    }
}

struct InspectorEditingTests {
    /// Bild, Video, Audio – in dieser Reihenfolge.
    private func project() -> Project {
        var project = Project()
        project.media = [Medium.Kind.image, .video, .audio].enumerated().map { index, kind in
            Medium(id: UUID(), kind: kind, fileName: "m\(index)", displayName: "m\(index)")
        }
        project.insertCues(for: project.media.map(\.id), at: 0)
        return project
    }

    private func allIDs(_ project: Project) -> Set<Cue.ID> {
        Set(project.cues.map(\.id))
    }

    @Test func multiSelectionSetsVolumeOnlyWhereThereIsSound() {
        var project = project()
        project.apply(.volume(0.4), to: allIDs(project))
        project.apply(.muted(true), to: allIDs(project))
        #expect(project.cues.map(\.volume) == [1, 0.4, 0.4])
        #expect(project.cues.map(\.isMuted) == [false, true, true])
    }

    @Test func multiSelectionSetsPictureValuesExceptForAudio() {
        var project = project()
        project.apply(.scaling(.fill), to: allIDs(project))
        project.apply(.blendIn(0.5), to: allIDs(project))
        #expect(project.cues.map(\.scaling) == [.fill, .fill, .fit])
        #expect(project.cues.map(\.blendIn) == [0.5, 0.5, 0])
    }

    @Test func notesAndColorApplyToSelectionButNameDoesNot() {
        #expect(CueEdit.notes("x").appliesToSelection)
        #expect(CueEdit.volume(1).appliesToSelection)
        #expect(!CueEdit.name("x").appliesToSelection)
        #expect(!CueEdit.medium(UUID()).appliesToSelection)
    }

    @Test func replacingMediumResetsTrimAndOutput() throws {
        var project = project()
        let audioCue = project.cues[2]
        project.cues[2].outPoint = 4
        project.apply(.medium(project.media[1].id), to: [audioCue.id])
        let cue = try #require(project.cue(withID: audioCue.id))
        #expect(cue.mediumID == project.media[1].id)
        #expect(cue.outPoint == nil)
        #expect(cue.outputID == project.outputs.first?.id)

        project.apply(.medium(project.media[2].id), to: [audioCue.id])
        #expect(project.cue(withID: audioCue.id)?.outputID == nil)
    }

    @Test func tabsAreGreyedOutWhenTheyDoNotApply() {
        #expect(!InspectorTab.picture.isApplicable(to: [.audio]))
        #expect(!InspectorTab.trim.isApplicable(to: [.image]))
        #expect(!InspectorTab.audio.isApplicable(to: [.image]))
        #expect(InspectorTab.audio.isApplicable(to: [.image, .video]))
        #expect(InspectorTab.layers.isApplicable(to: [.video]))
        #expect(!InspectorTab.layers.isApplicable(to: [.image, .image]))
        #expect(InspectorTab.general.isApplicable(to: [nil]))
        #expect(InspectorTab.allCases.allSatisfy { !$0.isApplicable(to: []) })
        #expect(InspectorTab.allCases.count == 6)
    }

    @Test func newFieldsHaveDefaultsWhenMissing() throws {
        let json = #"{"id":"\#(UUID().uuidString)","number":"1"}"#
        let cue = try JSONDecoder().decode(Cue.self, from: Data(json.utf8))
        #expect(cue.scaling == .fit && !cue.isMuted && cue.blendIn == 0 && cue.blendOut == 0)
    }
}

@MainActor
struct InspectorPlaybackTests {
    let clock = VirtualClock()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now })
    }

    @Test func frameCarriesVolumeAndFollowsLiveChanges() throws {
        var video = ShowFixture.cue(.video, duration: 10)
        video.audio = AudioLevel(volume: 0.5, fadeIn: 1)
        video.scaling = .fill
        engine.load(ShowFixture.show([video]))
        engine.go()
        let frame = try #require(engine.state.content.frame)
        #expect(frame.playback == PlaybackSettings(scaling: .fill, audio: AudioLevel(volume: 0.5, fadeIn: 1), playLength: 10))

        video.audio.volume = 0.2
        engine.update(ShowFixture.show([video]))
        #expect(engine.state.content.frame?.playback.audio.volume == 0.2)
        #expect(engine.state.content.frame?.step == frame.step)
    }

    @Test func blendInAndOutSetTransitions() {
        var video = ShowFixture.cue(.video, duration: 3)
        video.blendIn = 0.7
        video.blendOut = 1.2
        engine.load(ShowFixture.show([video]))
        engine.go()
        #expect(engine.state.transition == 0.7)
        clock.advance(by: 3)
        #expect(engine.state.transition == 1.2)
    }
}
