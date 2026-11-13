import Foundation
import Testing
@testable import MessePlayer

@MainActor
struct HelpAndSampleTests {
    @Test func parsesHelpMarkdown() {
        let blocks = HelpBlock.parse("# Titel\n\n## Abschnitt\nEin **Absatz**.\n- Punkt eins\n  - Punkt zwei\n")
        #expect(blocks == [.title("Titel"), .heading("Abschnitt"), .paragraph("Ein **Absatz**."), .bullet("Punkt eins"), .bullet("Punkt zwei")])
    }

    @Test func allHelpTopicsAreBundledWithTitles() {
        #expect(HelpTopic.all.count == 9)
        #expect(HelpTopic.all.first?.title == "Erste Schritte")
        #expect(HelpTopic.all.allSatisfy { !$0.blocks.isEmpty })
    }

    /// Die Übersicht nennt jede Taste der v2-Belegung genau einmal.
    @Test func shortcutOverviewListsTransportKeys() {
        let keys = ShortcutInfo.all.map(\.keys)
        for key in ["P", "B", "⇧B", "⌘.", "Esc", "↑ / ↓", "⌘G / ⇧⌘G", "⇧⌘M"] {
            #expect(keys.contains(key), "\(key) fehlt")
        }
        #expect(Set(keys).count == keys.count)
    }

    @Test func sampleProjectOpensWithGroupTextsAndAnimation() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = try SampleProject.ensure(in: folder)
        let (project, media) = try ProjectPackage.read(FileWrapper(url: url, options: []))

        #expect(project.media.count == 2)
        let group = try #require(project.groups.first)
        #expect(project.members(of: group).count == 2)
        #expect(project.cues.allSatisfy { !$0.layers.isEmpty })
        #expect(project.cues.flatMap(\.layers).contains { !$0.animation.isStatic })
        #expect(project.media.allSatisfy { media.url(for: $0, in: url).map { FileManager.default.fileExists(atPath: $0.path) } == true })
        // Zweiter Aufruf legt nichts neu an.
        #expect(try SampleProject.ensure(in: folder) == url)
    }
}
