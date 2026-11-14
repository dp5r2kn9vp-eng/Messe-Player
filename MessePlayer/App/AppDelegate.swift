import AppKit

/// Hält die app-weiten Dienste. Es gibt genau eine Cue-Engine, unabhängig davon, welche Projekte offen sind.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = CueEngine()
    let displays = DisplayService()
    let hotkeys = HotkeyService()
    let mediaLengths = MediaLengths()
    let routing = OutputRouting()
    private(set) lazy var outputWindows = OutputWindowManager(engine: engine, displays: displays, routing: routing)
    private let sleepGuard = SleepGuard()

    /// Keine Fenster-Wiederherstellung durch macOS: Der Start zeigt das Willkommensfenster,
    /// nur nach einem Absturz öffnet CueView selbst das letzte Projekt.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = outputWindows
        sleepGuard.start()
        registerHotkeys()
        hotkeys.start()
        // Ohne diese Ausnahme sähe jeder Testlauf beim nächsten echten Start wie ein Absturz aus.
        if !AppInfo.isTestHost, SessionStore.beginRun() { reopenLastProject() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        QuitConfirmation.confirm(isOutputActive: !engine.visibleCueIDs.isEmpty) ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard !AppInfo.isTestHost else { return }
        SessionStore.endRun()
    }

    /// Kein leeres Projekt und kein Öffnen-Dialog – stattdessen erscheint das Willkommensfenster.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    /// Nur nach Absturz oder Stromausfall: Das letzte Projekt samt Ausgabezustand kommt automatisch zurück.
    private func reopenLastProject() {
        guard let url = SessionStore.lastProjectURL, NSDocumentController.shared.documents.isEmpty else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }

    private func registerHotkeys() {
        hotkeys.register("b") { [engine] in
            engine.toggleBlack()
            return true
        }
        hotkeys.register("b", shift: true) { [engine] in
            guard let output = engine.playheadOutputID else { return false }
            engine.toggleBlack(output: output)
            return true
        }
        hotkeys.register(HotkeyService.space) { [engine] in
            guard engine.playheadID != nil else { return false }
            engine.go()
            return true
        }
        hotkeys.register("p") { [engine] in
            engine.togglePause()
        }
        // Esc nur, wenn der Ausgang den Bildschirm des Steuerfensters blockiert.
        // Mit externem Bildschirm stoppt Esc nicht versehentlich – dafür gibt es den Notfall-Stopp ⌘.
        hotkeys.register(HotkeyService.escape) { [engine, unowned self] in
            guard outputWindows.blocksControlScreen else { return false }
            engine.stopAll()
            return true
        }
    }
}
