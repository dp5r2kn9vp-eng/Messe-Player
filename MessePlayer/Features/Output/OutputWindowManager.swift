import Foundation
import Observation

/// Wo ein Ausgang gerade erscheint.
enum OutputStatus: Equatable {
    case screen(String)
    /// Bewusst keinem Bildschirm zugeordnet.
    case preview
    /// Zugeordneter Bildschirm ist abgesteckt; die Show läuft in der Vorschau weiter.
    case disconnected(String)

    var isPreview: Bool {
        if case .screen = self { false } else { true }
    }
}

/// Hält je logischem Ausgang ein Ausgabefenster und gleicht sie mit den Ausgängen der geladenen Cue-Liste ab.
@Observable
final class OutputWindowManager {
    private(set) var controllers: [OutputDefinition.ID: OutputWindowController] = [:]

    @ObservationIgnored private let engine: CueEngine
    @ObservationIgnored private let displays: DisplayService
    @ObservationIgnored private let routing: OutputRouting

    init(engine: CueEngine, displays: DisplayService, routing: OutputRouting) {
        self.engine = engine
        self.displays = displays
        self.routing = routing
        observeOutputs()
    }

    var outputs: [OutputDefinition] {
        engine.show.outputs
    }

    func status(of outputID: OutputDefinition.ID) -> OutputStatus {
        if let display = routing.display(for: outputID, in: displays.displays) {
            return .screen(display.name)
        }
        if let screen = routing.assignment(for: outputID)?.screen {
            return .disconnected(screen.name)
        }
        return .preview
    }

    /// Ein laufender Ausgang verdeckt das Steuerfenster (dann beendet Esc die Wiedergabe).
    var blocksControlScreen: Bool {
        controllers.values.contains { $0.sharesControlScreen && !$0.isIdle }
    }

    /// Zeigt auf jedem zugeordneten Bildschirm den Namen seines Ausgangs.
    func identifyScreens() {
        for (index, output) in outputs.enumerated() {
            controllers[output.id]?.identify(OutputIdentification(name: output.name, colorIndex: index))
        }
    }

    private func observeOutputs() {
        let ids = withObservationTracking {
            outputs.map(\.id)
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.observeOutputs() }
        }
        sync(ids)
    }

    /// Neue Ausgänge bekommen ein Fenster, entfernte verlieren es. Ohne geladene Liste bleiben die Fenster stehen.
    private func sync(_ ids: [OutputDefinition.ID]) {
        guard !ids.isEmpty else { return }
        for (id, controller) in controllers where !ids.contains(id) {
            controller.close()
            controllers[id] = nil
        }
        for id in ids where controllers[id] == nil {
            controllers[id] = OutputWindowController(outputID: id, engine: engine, displays: displays, routing: routing)
        }
    }
}
