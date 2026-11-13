import Foundation

/// Verhindert Ruhezustand von Bildschirm und Mac, solange die App läuft – am Messestand darf nichts ausgehen.
final class SleepGuard {
    private var activity: NSObjectProtocol?

    func start() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled, .userInitiated],
            reason: "CueView gibt auf einem Bildschirm aus"
        )
    }
}
