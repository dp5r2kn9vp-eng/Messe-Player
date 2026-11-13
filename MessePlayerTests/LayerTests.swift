import Foundation
import Testing
@testable import MessePlayer

/// Dokument mit je einem Bild-Cue pro Medium.
@MainActor
func documentWithCues(_ media: [Medium]) -> ProjectDocument {
    var document = ProjectDocument()
    document.project.media = media
    document.project.insertCues(for: media.map(\.id), at: 0)
    return document
}

@MainActor
struct LayerTests {
    private let logo = Medium(id: UUID(), kind: .image, fileName: "l.png", displayName: "Logo")
    private let package = URL(filePath: "/tmp/Show.klangshow")

    @Test func layersSurviveSaveRoundTrip() throws {
        var project = documentWithCues([logo]).project
        var text = Layer.text("Nächster Auftritt 15 Uhr")
        if case .text(var style) = text.content {
            style.fontName = "Avenir Next"
            style.background = RGBAColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.8)
            text.content = .text(style)
        }
        project.cues[0].layers = [text, .image(logo.id)]

        #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)
    }

    @Test func showResolvesImageLayersAndKeepsMissingOnes() throws {
        var document = documentWithCues([logo])
        document.project.cues[0].layers = [.image(logo.id), .image(UUID()), .text("Hallo")]

        guard case .media(_, let layers) = try #require(document.show(in: package).cues.first).content else {
            Issue.record("kein Medium")
            return
        }
        #expect(layers.map { $0.imageURL?.lastPathComponent } == ["l.png", nil, nil])
    }

    @Test func editingTextOfRunningCueUpdatesWithoutNewStep() throws {
        var document = documentWithCues([logo])
        document.project.cues[0].layers = [.text("15 Uhr")]
        let engine = CueEngine(scheduler: VirtualClock())
        engine.load(document.show(in: package))
        engine.go()
        let id = engine.state.content.transitionID

        document.project.cues[0].layers = [.text("16 Uhr")]
        engine.update(document.show(in: package))

        let frame = try #require(engine.state.content.frame)
        #expect(frame.layers.map(\.layer.content) == [Layer.text("16 Uhr").content])
        #expect(engine.state.content.transitionID == id)
    }
}

@MainActor
struct BrandingTests {
    @Test func logoLayerSurvivesRoundTripAndNeedsNoMedium() throws {
        let photo = Medium(id: UUID(), kind: .image, fileName: "p.jpg", displayName: "p")
        var document = documentWithCues([photo])
        document.project.cues[0].layers = [.logo()]

        #expect(try ProjectCodec.decode(ProjectCodec.encode(document.project)) == document.project)
        guard case .media(_, let layers) = try #require(document.show(in: URL(filePath: "/tmp/Show.klangshow")).cues.first).content else {
            Issue.record("kein Medium")
            return
        }
        #expect(layers.first?.layer.content == .logo)
        #expect(layers.first?.imageURL == nil)
    }
}
