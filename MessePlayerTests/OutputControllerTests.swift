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
}
