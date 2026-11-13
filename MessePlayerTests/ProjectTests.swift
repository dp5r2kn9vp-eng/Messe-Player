import Foundation
import Testing
@testable import MessePlayer

struct ProjectTests {
    @Test func newProjectUsesCurrentSchemaVersion() {
        #expect(Project().schemaVersion == Project.currentSchemaVersion)
    }

    @Test func roundTripsThroughJSON() throws {
        let project = Project()
        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
        #expect(decoded == project)
    }
}
