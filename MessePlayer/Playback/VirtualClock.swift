import Foundation

/// Zeitgeber mit virtueller Uhr für Simulation (Zeitstrahl) und Tests: Schritte laufen in zeitlicher Reihenfolge, ohne echtes Warten.
final class VirtualClock: StepScheduler {
    private(set) var now: Date
    private var pending: [(id: Int, fireAt: Date, action: () -> Void)] = []
    private var nextID = 0

    init(now: Date = Date(timeIntervalSince1970: 1_000)) {
        self.now = now
    }

    var pendingCount: Int { pending.count }

    func schedule(after delay: Duration, _ action: @escaping () -> Void) -> Cancellation {
        nextID += 1
        let id = nextID
        let seconds = Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
        pending.append((id, now + seconds, action))
        return Cancellation { [weak self] in self?.pending.removeAll { $0.id == id } }
    }

    /// Führt alle bis `now + seconds` fälligen Schritte aus.
    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while let next = nextPending, next.fireAt <= target {
            fire(next)
        }
        now = target
    }

    /// Springt zum nächsten fälligen Schritt und führt ihn aus; `false`, wenn nichts mehr ansteht.
    @discardableResult
    func runNext() -> Bool {
        guard let next = nextPending else { return false }
        fire(next)
        return true
    }

    private var nextPending: (id: Int, fireAt: Date, action: () -> Void)? {
        pending.min { ($0.fireAt, $0.id) < ($1.fireAt, $1.id) }
    }

    private func fire(_ step: (id: Int, fireAt: Date, action: () -> Void)) {
        pending.removeAll { $0.id == step.id }
        now = max(now, step.fireAt)
        step.action()
    }
}
