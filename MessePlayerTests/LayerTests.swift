import Foundation
import Testing
@testable import MessePlayer

@MainActor
struct LayerTests {
    @Test func layersSurviveSaveRoundTrip() throws {
        var project = Project()
        let logo = Medium(id: UUID(), kind: .image, fileName: "l.png", displayName: "Logo")
        project.media = [logo]
        let groupID = project.addGroup()
        project.addEntries(for: [logo.id], toGroup: groupID)
        var text = Layer.text("Nächster Auftritt 15 Uhr")
        if case .text(var style) = text.content {
            style.fontName = "Avenir Next"
            style.background = RGBAColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 0.8)
            text.content = .text(style)
        }
        project.groups[0].entries[0].layers = [text, .image(logo.id)]

        #expect(try ProjectCodec.decode(ProjectCodec.encode(project)) == project)
    }

    @Test func playlistResolvesImageLayersAndKeepsMissingOnes() throws {
        var document = ProjectDocument()
        let logo = Medium(id: UUID(), kind: .image, fileName: "l.png", displayName: "Logo")
        document.project.media = [logo]
        let groupID = document.project.addGroup()
        document.project.addEntries(for: [logo.id], toGroup: groupID)
        document.project.groups[0].entries[0].layers = [.image(logo.id), .image(UUID()), .text("Hallo")]

        let package = URL(filePath: "/tmp/Show.klangshow")
        let layers = try #require(document.playlist(for: document.project.groups[0], in: package).items.first).layers
        #expect(layers.map { $0.imageURL?.lastPathComponent } == ["l.png", nil, nil])
    }

    @Test func editingTextOfRunningEntryUpdatesWithoutNewStep() throws {
        let scheduler = ManualScheduler()
        let output = OutputController(scheduler: scheduler)
        let medium = Medium(id: UUID(), kind: .image, fileName: "x", displayName: "x")
        let playable = PlayableMedium(medium: medium, url: URL(filePath: "/tmp/x"))
        let entryID = UUID()
        let groupID = UUID()
        let before = RenderLayer(layer: .text("15 Uhr"), imageURL: nil)
        let after = RenderLayer(layer: .text("16 Uhr"), imageURL: nil)

        output.startLoop(LoopPlaylist(groupID: groupID, crossfade: 0, items: [LoopItem(entryID: entryID, item: playable, imageDuration: 5, layers: [before])]))
        let id = output.state.content.transitionID
        output.updateLoop(LoopPlaylist(groupID: groupID, crossfade: 0, items: [LoopItem(entryID: entryID, item: playable, imageDuration: 5, layers: [after])]))

        guard case .loop(let frame) = output.state.content else { Issue.record("kein Loop"); return }
        #expect(frame.layers == [after])
        #expect(output.state.content.transitionID == id)
    }
}
