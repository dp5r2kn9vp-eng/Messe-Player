import Foundation
import Testing
@testable import MessePlayer

struct CueTrimTests {
    @Test func durationIsOutMinusIn() {
        #expect(CueTrim(inPoint: 5, outPoint: 47.5, mediaLength: 72).duration == 42.5)
        #expect(CueTrim(inPoint: 5, outPoint: nil, mediaLength: 72).duration == 67)
        #expect(CueTrim(inPoint: 5, outPoint: nil, mediaLength: nil).duration == nil)
        #expect(!CueTrim(mediaLength: 72).isTrimmed)
    }

    @Test func inPointStaysBeforeOutPoint() {
        var trim = CueTrim(inPoint: 0, outPoint: 20, mediaLength: 60)
        trim.setIn(-3)
        #expect(trim.inPoint == 0)
        trim.setIn(30)
        #expect(trim.inPoint == 20 - CueTrim.minimumLength)
        trim.setIn(4)
        #expect(trim.inPoint == 4)
    }

    @Test func outPointStaysBehindInAndResetsAtMediaEnd() {
        var trim = CueTrim(inPoint: 10, outPoint: nil, mediaLength: 60)
        trim.setOut(5)
        #expect(trim.outPoint == 10 + CueTrim.minimumLength)
        trim.setOut(45)
        #expect(trim.outPoint == 45)
        trim.setOut(60)
        #expect(trim.outPoint == nil)
        trim.setOut(80)
        #expect(trim.outPoint == nil)
    }

    @Test func shorteningDurationSetsOutPoint() {
        var trim = CueTrim(inPoint: 5, outPoint: nil, mediaLength: 60)
        trim.setDuration(20)
        #expect(trim.outPoint == 25)
        #expect(trim.duration == 20)
        trim.setDuration(500)
        #expect(trim.outPoint == nil)
        #expect(trim.duration == 55)
    }

    @Test func resetRestoresFullLength() {
        var trim = CueTrim(inPoint: 3, outPoint: 9, mediaLength: 60)
        trim.reset()
        #expect(trim == CueTrim(mediaLength: 60))
    }

    @Test func scaleMapsTimeAndPosition() {
        let scale = TrimScale(length: 60, width: 300)
        #expect(scale.x(30) == 150)
        #expect(scale.x(90) == 300)
        #expect(scale.time(75) == 15)
        #expect(scale.time(-10) == 0)
    }

    @Test func peaksKeepLargestMagnitudePerBucket() {
        var accumulator = PeakAccumulator(totalSamples: 6, peakCount: 3)
        let samples: [Float] = [0.1, -0.5, 0.2, 0.3, -2, 0.4, 0.05]
        samples.withUnsafeBufferPointer { accumulator.add($0) }
        #expect(accumulator.finish() == [0.5, 0.3, 1, 0.05])
    }
}

struct TrimEditingTests {
    private func project(kind: Medium.Kind) -> Project {
        var project = Project()
        project.media = [Medium(id: UUID(), kind: kind, fileName: "m", displayName: "m")]
        project.insertCues(for: project.media.map(\.id), at: 0)
        return project
    }

    @Test func pointsAreSetPerCueAndShowInDuration() {
        var project = project(kind: .video)
        let id = project.cues[0].id
        project.apply(.inPoint(5), to: [id], mediaLength: { _ in 72.4 })
        project.apply(.outPoint(47.5), to: [id], mediaLength: { _ in 72.4 })
        #expect(project.cues[0].inPoint == 5)
        #expect(project.cues[0].outPoint == 47.5)
        #expect(project.duration(of: project.cues[0], mediaLength: 72.4) == 42.5)

        project.apply(.duration(10), to: [id], mediaLength: { _ in 72.4 })
        #expect(project.cues[0].outPoint == 15)

        project.apply(.resetTrim, to: [id], mediaLength: { _ in 72.4 })
        #expect(project.cues[0].inPoint == 0 && project.cues[0].outPoint == nil)
    }

    @Test func imagesIgnoreTrimAndPointsNeverApplyToSelection() {
        var project = project(kind: .image)
        let id = project.cues[0].id
        project.apply(.inPoint(2), to: [id])
        #expect(project.cues[0].inPoint == 0)
        #expect(!CueEdit.inPoint(1).appliesToSelection)
        #expect(!CueEdit.outPoint(1).appliesToSelection)
        #expect(CueEdit.resetTrim.appliesToSelection)
    }

    @Test func previewPlaysOnlyTrimmedRange() {
        var cue = Cue(number: "1")
        cue.inPoint = 4
        cue.outPoint = 14
        cue.fadeIn = 1
        let playback = PlaybackSettings.trimmed(cue, mediaLength: 60)
        #expect(playback.startTime == 4)
        #expect(playback.endTime == 14)
        #expect(playback.playLength == 10)
        // Rampen in Medienzeit beginnen am In-Punkt.
        #expect(playback.audio.ramps(from: playback.startTime, length: playback.playLength).map(\.start) == [4])
    }
}

@MainActor
struct TrimPlaybackTests {
    let clock = VirtualClock()
    let audio = RecordingAudioOutput()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: audio)
    }

    @Test func engineHandsTrimToVideoAndAudio() throws {
        var video = ShowFixture.cue(.video, duration: 10)
        video.inPoint = 3
        video.outPoint = 13
        var sound = ShowFixture.cue(.audio, duration: 4, follow: .hold)
        sound.inPoint = 1
        sound.outPoint = 5
        video.followAction = .continueWithNext
        engine.load(ShowFixture.show([video, sound]))
        engine.go()
        let frame = try #require(engine.state.content.frame)
        #expect(frame.playback.startTime == 3 && frame.playback.endTime == 13)
        let played = try #require(audio.playing[sound.id])
        #expect(played.playback.startTime == 1 && played.playback.endTime == 5)
    }
}
