import Foundation

/// Laufzeit einer Phase (Warten oder Dauer), für den Restzeit-Balken.
struct StepProgress: Equatable {
    let startedAt: Date
    let duration: TimeInterval
    /// Gesetzt, solange pausiert ist; der Balken bleibt dann stehen.
    var pausedAt: Date?

    func remaining(at now: Date) -> TimeInterval {
        max(duration - (pausedAt ?? now).timeIntervalSince(startedAt), 0)
    }

    /// Nach einer Pause um die angehaltene Zeit verschoben.
    func resumed(at now: Date) -> StepProgress {
        guard let pausedAt else { return self }
        return StepProgress(startedAt: startedAt + now.timeIntervalSince(pausedAt), duration: duration)
    }
}
