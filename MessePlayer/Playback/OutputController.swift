import Observation

/// Einzige Quelle des Ausgabezustands; Steuer- und Ausgabefenster teilen sich diese Instanz.
@Observable
final class OutputController {
    private(set) var state = OutputState()

    /// Black wirkt sofort und ohne Überblendung.
    func toggleBlack() {
        state.isBlack.toggle()
    }
}
