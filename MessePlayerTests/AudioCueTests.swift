import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MessePlayer

/// Ersatz für die Systemausgabe: merkt sich, was die Engine an den Ton weitergibt.
final class RecordingAudioOutput: AudioCueOutput {
    enum Call: Equatable {
        case play(Cue.ID)
        case update(Cue.ID, PlaybackSettings)
        case stop(Cue.ID, fadeOut: TimeInterval)
        case paused(Bool)
    }

    private(set) var calls: [Call] = []
    private(set) var playing: [Cue.ID: AudioCuePlayback] = [:]
    private var finishers: [Cue.ID: () -> Void] = [:]

    func play(_ playback: AudioCuePlayback, onFinish: @escaping () -> Void) {
        calls.append(.play(playback.cueID))
        playing[playback.cueID] = playback
        finishers[playback.cueID] = onFinish
    }

    func update(_ cueID: Cue.ID, playback: PlaybackSettings) {
        calls.append(.update(cueID, playback))
        playing[cueID]?.playback = playback
    }

    func stop(_ cueID: Cue.ID, fadeOut: TimeInterval) {
        calls.append(.stop(cueID, fadeOut: fadeOut))
        playing[cueID] = nil
        finishers[cueID] = nil
    }

    func setPaused(_ paused: Bool) {
        calls.append(.paused(paused))
    }

    /// Simuliert das Ende der Datei.
    func finish(_ cueID: Cue.ID) {
        finishers[cueID]?()
    }
}

@MainActor
struct AudioCueTests {
    let clock = VirtualClock()
    let audio = RecordingAudioOutput()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now }, audio: audio)
    }

    private func music(length: TimeInterval? = 12, follow: FollowAction = .hold) -> ShowCue {
        var cue = ShowFixture.cue(.audio, duration: length, follow: follow)
        cue.endsWithMedia = true
        return cue
    }

    // MARK: Engine-Anbindung

    @Test func audioCueOccupiesNoOutput() {
        let image = ShowFixture.cue(.image)
        let sound = music()
        engine.load(ShowFixture.show([image, sound]))
        engine.go()
        engine.go()
        #expect(engine.state(for: ShowFixture.outputA1).content.frame?.cueID == image.id)
        #expect(engine.visibleCueIDs == [image.id])
        #expect(engine.running[sound.id]?.phase == .running)
        #expect(audio.playing.keys.contains(sound.id))
    }

    @Test func musicStartsWithLoopAndEndsWithFileWhileLoopContinues() {
        let sound = music(follow: .continueWithNext)
        let loop = (0..<2).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show([sound] + loop, groups: [(1...2, .loop)]))
        engine.go()
        #expect(audio.calls == [.play(sound.id)])
        #expect(engine.visibleCueIDs == [loop[0].id])

        clock.advance(by: 12)
        #expect(engine.running[sound.id] != nil, "Ende meldet der Player, nicht die Uhr")
        audio.finish(sound.id)
        #expect(engine.running[sound.id] == nil)
        #expect(audio.calls.last == .stop(sound.id, fadeOut: 0))
        clock.advance(by: 5)
        #expect(engine.visibleCueIDs == [loop[1].id])
    }

    @Test func audioEndTriggersFollowAction() {
        let sound = music(follow: .followOnEnd)
        let image = ShowFixture.cue(.image)
        engine.load(ShowFixture.show([sound, image]))
        engine.go()
        audio.finish(sound.id)
        #expect(engine.visibleCueIDs == [image.id])
    }

    @Test func trimmedAudioEndsByTime() {
        let sound = ShowFixture.cue(.audio, duration: 3, follow: .followOnEnd)
        let image = ShowFixture.cue(.image)
        engine.load(ShowFixture.show([sound, image]))
        engine.go()
        clock.advance(by: 3)
        #expect(audio.playing.isEmpty)
        #expect(engine.visibleCueIDs == [image.id])
    }

    @Test func audioWaitsBeforeStarting() {
        let sound = ShowFixture.cue(.audio, wait: 2)
        engine.load(ShowFixture.show([sound]))
        engine.go()
        #expect(audio.calls.isEmpty)
        clock.advance(by: 2)
        #expect(audio.calls == [.play(sound.id)])
    }

    @Test func lateFinishOfRestartedCueIsIgnored() {
        let sound = music()
        engine.load(ShowFixture.show([sound]))
        engine.go()
        let firstStep = audio.playing[sound.id]?.step
        engine.start(sound.id)
        #expect(audio.calls == [.play(sound.id), .stop(sound.id, fadeOut: CueEngine.audioStopFade), .play(sound.id)])
        engine.mediaDidFinish(cueID: sound.id, step: firstStep ?? 0)
        #expect(engine.running[sound.id] != nil)
    }

    @Test func pauseAndResumeReachAudio() {
        let sound = music()
        engine.load(ShowFixture.show([sound]))
        engine.go()
        engine.togglePause()
        engine.togglePause()
        #expect(audio.calls == [.play(sound.id), .paused(true), .paused(false)])
    }

    @Test func stopAllFadesAudioShortly() {
        let sound = music()
        engine.load(ShowFixture.show([sound]))
        engine.go()
        engine.stopAll()
        #expect(audio.calls.last == .stop(sound.id, fadeOut: CueEngine.audioStopFade))
        #expect(engine.running.isEmpty)
    }

    @Test func emergencyStopCutsAudioHardAndEndsPause() {
        let sound = music()
        engine.load(ShowFixture.show([sound]))
        engine.go()
        engine.togglePause()
        engine.emergencyStop()
        #expect(audio.calls.suffix(2) == [.stop(sound.id, fadeOut: 0), .paused(false)])
        #expect(!engine.isPaused)
    }

    @Test func volumeAndLengthChangesReachRunningAudio() {
        var sound = music(length: nil)
        engine.load(ShowFixture.show([sound]))
        engine.go()
        #expect(audio.playing[sound.id]?.playback.playLength == nil)

        sound.audio.volume = 0.5
        sound.duration = 30
        engine.update(ShowFixture.show([sound]))
        #expect(audio.playing[sound.id]?.playback.audio.volume == 0.5)
        #expect(audio.playing[sound.id]?.playback.playLength == 30)
    }

    @Test func deletedAudioCueFadesOut() {
        let sound = music()
        engine.load(ShowFixture.show([sound]))
        engine.go()
        engine.update(ShowFixture.show([]))
        #expect(audio.calls.last == .stop(sound.id, fadeOut: CueEngine.audioStopFade))
    }

    // MARK: Import und Auflösung

    @Test(arguments: ["wav", "aiff", "mp3", "m4a"])
    func audioFilesAreAudio(_ fileExtension: String) throws {
        let type = try #require(UTType(filenameExtension: fileExtension))
        #expect(Medium.Kind(contentType: type) == .audio)
    }

    @Test func importedAudioBecomesCueWithoutOutputThatEndsWithFile() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "Musik.mp3")
        try Data("x".utf8).write(to: file)

        var document = ProjectDocument()
        _ = document.importMedia(from: [file], at: 0)
        let medium = try #require(document.project.media.first)
        #expect(medium.kind == .audio)
        document.project.insertCues(for: [medium.id], at: 0)

        let cue = try #require(document.show(in: nil, mediaLength: { _ in 42 }).cues.first)
        #expect(cue.isAudio)
        #expect(cue.outputID == nil)
        #expect(cue.endsWithMedia)
        #expect(cue.duration == 42)
    }
}
