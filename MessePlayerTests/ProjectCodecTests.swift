import Foundation
import Testing
@testable import MessePlayer

struct ProjectCodecTests {
    @Test func newProjectUsesCurrentSchemaVersion() {
        #expect(Project().schemaVersion == Project.currentSchemaVersion)
    }

    @Test func rejectsNewerSchemaWithClearError() {
        let json = Data(#"{"schemaVersion": 99, "media": []}"#.utf8)
        #expect(throws: ProjectError.newerSchema(99)) { try ProjectCodec.decode(json) }
    }

    @Test func rejectsUnknownOlderSchema() {
        let json = Data(#"{"schemaVersion": 0, "media": []}"#.utf8)
        #expect(throws: ProjectError.unsupportedSchema(0)) { try ProjectCodec.decode(json) }
    }
}
