import Observation

/// Einzige Quelle des Ausgabezustands; Steuer- und Ausgabefenster teilen sich diese Instanz.
@Observable
final class OutputController {
    private(set) var state = OutputState()

    /// Black wirkt sofort und ohne Überblendung.
    func toggleBlack() {
        state.isBlack.toggle()
    }

    /// Zeigt ein Medium dauerhaft und ersetzt einen laufenden Loop. Black bleibt bestehen.
    func showSingle(_ item: PlayableMedium) {
        state.content = .single(item)
    }

    func isLive(_ medium: Medium) -> Bool {
        guard case .single(let item) = state.content else { return false }
        return item.medium.id == medium.id
    }
}
