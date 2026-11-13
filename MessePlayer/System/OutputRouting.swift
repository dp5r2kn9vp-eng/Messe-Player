import Foundation
import Observation

/// Bildschirm, wie er je Rechner gespeichert wird: UUID (stabil über Neustarts) und Name als Rückfall.
nonisolated struct ScreenIdentity: Codable, Hashable {
    var uuid: String?
    var name: String
}

/// Zuordnung eines logischen Ausgangs; `screen == nil` = bewusst Vorschau im Steuerfenster.
nonisolated struct OutputAssignment: Codable, Equatable {
    var screen: ScreenIdentity?
}

/// Zuordnung logischer Ausgang → Bildschirm, gespeichert je Rechner in den Benutzereinstellungen
/// (nicht im Projekt), damit ein Projekt auf jedem Rechner und mit jeder Bildschirmzahl nutzbar bleibt.
@Observable
final class OutputRouting {
    private static let key = "outputRouting"

    private(set) var assignments: [OutputDefinition.ID: OutputAssignment]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        assignments = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([OutputDefinition.ID: OutputAssignment].self, from: $0) } ?? [:]
    }

    func assignment(for outputID: OutputDefinition.ID) -> OutputAssignment? {
        assignments[outputID]
    }

    func assign(_ outputID: OutputDefinition.ID, to screen: ScreenIdentity?) {
        assignments[outputID] = OutputAssignment(screen: screen)
        save()
    }

    /// Ausgänge ohne gespeicherte Zuordnung auf diesem Rechner.
    func unassigned(_ outputs: [OutputDefinition]) -> [OutputDefinition] {
        outputs.filter { assignments[$0.id] == nil }
    }

    /// Angeschlossener Bildschirm des Ausgangs; `nil` = Vorschau (nicht zugeordnet oder abgesteckt).
    func display(for outputID: OutputDefinition.ID, in displays: [Display]) -> Display? {
        assignments[outputID]?.screen.flatMap { $0.match(in: displays) }
    }

    /// Zugeordnet, aber der Bildschirm fehlt gerade (abgesteckt).
    func isDisconnected(_ outputID: OutputDefinition.ID, in displays: [Display]) -> Bool {
        guard let screen = assignments[outputID]?.screen else { return false }
        return screen.match(in: displays) == nil
    }

    /// Vorschlag für Ausgänge ohne Zuordnung: der frühere CueView-Bildschirm bzw. die externen Bildschirme
    /// der Reihe nach; der erste Ausgang notfalls auf dem Steuerbildschirm, weitere in die Vorschau.
    func proposals(for outputs: [OutputDefinition], displays: [Display], legacyName: String?) -> [OutputDefinition.ID: ScreenIdentity?] {
        let taken = Set(assignments.values.compactMap { $0.screen?.match(in: displays)?.id })
        var free = displays.filter { !$0.isControlScreen && !taken.contains($0.id) }
        if let legacy = free.firstIndex(where: { $0.name == legacyName }) {
            free.insert(free.remove(at: legacy), at: 0)
        }
        var result: [OutputDefinition.ID: ScreenIdentity?] = [:]
        for (index, output) in outputs.enumerated() where assignments[output.id] == nil {
            if !free.isEmpty {
                result[output.id] = free.removeFirst().identity
            } else if index == 0, let control = displays.first(where: \.isControlScreen) {
                result[output.id] = control.identity
            } else {
                result[output.id] = .some(nil)
            }
        }
        return result
    }

    /// Beim Öffnen: Ausgänge ohne Zuordnung bekommen den Vorschlag gespeichert. `true`, wenn der Nutzer
    /// prüfen soll (mehrere Ausgänge, davon mindestens einer neu auf diesem Rechner).
    func proposeMissing(for outputs: [OutputDefinition], displays: [Display], legacyName: String?) -> Bool {
        guard !unassigned(outputs).isEmpty else { return false }
        for (id, screen) in proposals(for: outputs, displays: displays, legacyName: legacyName) {
            assign(id, to: screen)
        }
        return outputs.count > 1
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(assignments), forKey: Self.key)
    }
}

nonisolated extension ScreenIdentity {
    /// Erst über die UUID, sonst über den Namen (z. B. nach Tausch des Adapters).
    func match(in displays: [Display]) -> Display? {
        displays.first { uuid != nil && $0.uuid == uuid } ?? displays.first { $0.name == name }
    }
}
