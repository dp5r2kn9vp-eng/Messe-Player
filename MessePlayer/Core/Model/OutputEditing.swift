import Foundation

/// Logische Ausgänge des Projekts anlegen, umbenennen und entfernen. Es bleibt immer mindestens einer.
nonisolated extension Project {
    /// Legt „Ausgang n“ mit der kleinsten freien Nummer an.
    @discardableResult
    mutating func addOutput() -> OutputDefinition.ID {
        let names = Set(outputs.map(\.name))
        let number = (1...).first { !names.contains(OutputDefinition.numbered($0).name) } ?? outputs.count + 1
        let output = OutputDefinition.numbered(number)
        outputs.append(output)
        return output.id
    }

    mutating func renameOutput(_ id: OutputDefinition.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = outputs.firstIndex(where: { $0.id == id }) else { return }
        outputs[index].name = trimmed
    }

    var canRemoveOutput: Bool { outputs.count > 1 }

    /// Entfernt einen Ausgang; seine Cues wechseln auf den ersten verbleibenden Ausgang.
    mutating func removeOutput(_ id: OutputDefinition.ID) {
        guard canRemoveOutput else { return }
        outputs.removeAll { $0.id == id }
        let fallback = outputs.first?.id
        for index in cues.indices where cues[index].outputID == id {
            cues[index].outputID = fallback
        }
    }
}
