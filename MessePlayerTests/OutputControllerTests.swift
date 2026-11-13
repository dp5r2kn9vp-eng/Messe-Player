import Foundation
import Testing
@testable import MessePlayer

@MainActor
struct OutputControllerTests {
    @Test func startsIdleAndVisible() {
        let output = OutputController()
        #expect(output.state == OutputState(content: .idle, isBlack: false))
    }

    @Test func blackTogglesAndRestoresContent() {
        let output = OutputController()
        output.toggleBlack()
        #expect(output.state.isBlack)
        output.toggleBlack()
        #expect(output.state == OutputState())
    }

    private func item(_ name: String) -> PlayableMedium {
        PlayableMedium(
            medium: Medium(id: UUID(), kind: .video, fileName: name, displayName: name),
            url: URL(filePath: "/tmp/\(name)")
        )
    }

    @Test func showSingleReplacesContentAndMarksLive() {
        let output = OutputController()
        let clip = item("Clip.mov")
        output.showSingle(clip)
        #expect(output.state.content == .single(clip))
        #expect(output.isLive(clip.medium))
        #expect(!output.isLive(item("Anderes.mov").medium))
    }

    @Test func blackStaysActiveWhenSwitchingContent() {
        let output = OutputController()
        output.toggleBlack()
        output.showSingle(item("Clip.mov"))
        #expect(output.state.isBlack)
    }
}
