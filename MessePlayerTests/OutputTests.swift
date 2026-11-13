import Foundation
import Testing
@testable import MessePlayer

/// Mehrere Ausgänge: Ersetzen und Black je Ausgang in der Engine.
@MainActor
struct OutputEngineTests {
    let clock = VirtualClock()
    let engine: CueEngine

    init() {
        let clock = clock
        engine = CueEngine(scheduler: clock, now: { clock.now })
    }

    private func visible(on output: UUID) -> Cue.ID? {
        engine.state(for: output).content.frame?.cueID
    }

    @Test func newCueReplacesOnlyItsOwnOutput() {
        let cues = [
            ShowFixture.cue(.image, duration: 0, follow: .continueWithNext),
            ShowFixture.cue(.image, duration: 0, output: ShowFixture.outputA2),
            ShowFixture.cue(.image, duration: 0),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.go()
        #expect(visible(on: ShowFixture.outputA1) == cues[2].id)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)
        // Überblendung des ersetzenden Cues gilt nur für seinen Ausgang.
        #expect(engine.state(for: ShowFixture.outputA2).content.frame?.step != engine.state(for: ShowFixture.outputA1).content.frame?.step)
    }

    @Test func runningVideoOnOtherOutputKeepsRunning() {
        let cues = [
            ShowFixture.cue(.video, duration: 30, output: ShowFixture.outputA2),
            ShowFixture.cue(.image, duration: 5),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.go()
        clock.advance(by: 10)
        #expect(engine.running[cues[0].id]?.phase == .running)
        #expect(visible(on: ShowFixture.outputA2) == cues[0].id)
    }

    @Test func blackPerOutputLeavesOthersAndCuesRunning() {
        let cues = [
            ShowFixture.cue(.image, follow: .continueWithNext),
            ShowFixture.cue(.image, output: ShowFixture.outputA2),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        engine.toggleBlack(output: ShowFixture.outputA2)
        #expect(engine.state(for: ShowFixture.outputA2).isBlack)
        #expect(!engine.state(for: ShowFixture.outputA1).isBlack)
        #expect(visible(on: ShowFixture.outputA2) == cues[1].id)

        engine.toggleBlack()
        #expect(engine.state(for: ShowFixture.outputA1).isBlack)
        engine.toggleBlack()
        #expect(engine.state(for: ShowFixture.outputA2).isBlack)
        engine.toggleBlack(output: ShowFixture.outputA2)
        #expect(!engine.state(for: ShowFixture.outputA2).isBlack)
    }

    @Test func shiftBTargetsOutputOfPlayheadCue() {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image, output: ShowFixture.outputA2), ShowFixture.cue(.audio)]
        engine.load(ShowFixture.show(cues))
        #expect(engine.playheadOutputID == ShowFixture.outputA1)
        engine.setPlayhead(cues[1].id)
        #expect(engine.playheadOutputID == ShowFixture.outputA2)
        engine.setPlayhead(cues[2].id)
        #expect(engine.playheadOutputID == ShowFixture.outputA1)
    }

    @Test func countsParallelVideos() {
        let cues = [
            ShowFixture.cue(.video, duration: 30, follow: .continueWithNext),
            ShowFixture.cue(.video, duration: 30, follow: .continueWithNext, output: ShowFixture.outputA2),
            ShowFixture.cue(.image),
        ]
        engine.load(ShowFixture.show(cues))
        engine.go()
        // Das Bild ersetzt das Video auf Ausgang 1.
        #expect(engine.parallelVideoCount == 1)
    }

    @Test func blackPerOutputSurvivesRestart() throws {
        var document = documentWithCues([Medium(id: UUID(), kind: .image, fileName: "A.png", displayName: "A")])
        let second = document.project.addOutput()
        let package = URL(filePath: "/tmp/Messe.klangshow")
        engine.load(document.show(in: package))
        engine.toggleBlack(output: second)
        let snapshot = engine.snapshot(projectPath: package.path)

        let after = CueEngine(scheduler: VirtualClock())
        after.load(document.show(in: package))
        after.restore(snapshot)
        #expect(after.blackOutputIDs == [second])
        #expect(!after.isBlack)
    }
}

/// Zuordnung Ausgang → Bildschirm je Rechner und Ausgänge im Projekt.
@MainActor
struct OutputRoutingTests {
    let control = Display(id: 1, name: "Eingebautes Display", uuid: "U-1", isControlScreen: true)
    let tvLeft = Display(id: 2, name: "TV links", uuid: "U-2", isControlScreen: false)
    let tvRight = Display(id: 3, name: "TV rechts", uuid: "U-3", isControlScreen: false)

    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: UUID().uuidString))
    }

    @Test func assignmentPersistsPerMachine() throws {
        let defaults = try defaults()
        let output = UUID()
        OutputRouting(defaults: defaults).assign(output, to: tvRight.identity)
        let reloaded = OutputRouting(defaults: defaults)
        #expect(reloaded.display(for: output, in: [control, tvLeft, tvRight]) == tvRight)
        #expect(reloaded.unassigned([OutputDefinition(id: output, name: "A")]).isEmpty)
    }

    @Test func assignmentIsNotStoredInProject() throws {
        var project = Project()
        project.addOutput()
        let routing = OutputRouting(defaults: try defaults())
        routing.assign(project.outputs[0].id, to: tvLeft.identity)
        let json = String(decoding: try ProjectCodec.encode(project), as: UTF8.self)
        #expect(!json.contains(tvLeft.name))
        #expect(!json.contains("U-2"))
    }

    @Test func screenMatchesByUUIDThenName() {
        let moved = Display(id: 9, name: "TV links", uuid: "U-2", isControlScreen: false)
        #expect(tvLeft.identity.match(in: [control, moved]) == moved)
        let renamedAdapter = Display(id: 8, name: "TV links", uuid: "U-X", isControlScreen: false)
        #expect(ScreenIdentity(uuid: "U-2", name: "TV links").match(in: [renamedAdapter]) == renamedAdapter)
    }

    @Test func unpluggedScreenMeansPreview() throws {
        let routing = OutputRouting(defaults: try defaults())
        let output = UUID()
        routing.assign(output, to: tvLeft.identity)
        #expect(routing.display(for: output, in: [control]) == nil)
        #expect(routing.isDisconnected(output, in: [control]))
        routing.assign(output, to: nil)
        #expect(!routing.isDisconnected(output, in: [control]))
    }

    @Test func proposalsUseExternalScreensInOrder() throws {
        let routing = OutputRouting(defaults: try defaults())
        let outputs = [OutputDefinition.numbered(1), .numbered(2), .numbered(3)]
        let proposal = routing.proposals(for: outputs, displays: [control, tvLeft, tvRight], legacyName: "TV rechts")
        #expect(proposal[outputs[0].id] == .some(tvRight.identity))
        #expect(proposal[outputs[1].id] == .some(tvLeft.identity))
        #expect(proposal[outputs[2].id] == .some(nil))
    }

    @Test func singleScreenPutsFirstOutputOnControlScreen() throws {
        let routing = OutputRouting(defaults: try defaults())
        let outputs = [OutputDefinition.numbered(1), .numbered(2)]
        #expect(routing.proposeMissing(for: outputs, displays: [control], legacyName: nil))
        #expect(routing.display(for: outputs[0].id, in: [control]) == control)
        #expect(routing.assignment(for: outputs[1].id) == OutputAssignment(screen: nil))
        // Bereits zugeordnet: kein erneuter Dialog.
        #expect(!routing.proposeMissing(for: outputs, displays: [control], legacyName: nil))
    }

    @Test func addAndRemoveOutputs() {
        var project = Project()
        let second = project.addOutput()
        #expect(project.outputs.map(\.name) == ["Ausgang 1", "Ausgang 2"])
        project.cues = [Cue(number: "1", outputID: second)]
        project.renameOutput(second, to: "  LED-Wand ")
        #expect(project.outputs[1].name == "LED-Wand")
        project.removeOutput(second)
        #expect(project.cues[0].outputID == project.outputs[0].id)
        project.removeOutput(project.outputs[0].id)
        #expect(project.outputs.count == 1)
        #expect(project.validationIssues.isEmpty)
    }
}
