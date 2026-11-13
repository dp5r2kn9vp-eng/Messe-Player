import AppKit

/// Hält die app-weiten Dienste. Es gibt genau einen Ausgang, unabhängig davon, welche Projekte offen sind.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let output = OutputController()
    let displays = DisplayService()
    let hotkeys = HotkeyService()
    let mediaLengths = MediaLengths()
    private(set) lazy var outputWindow = OutputWindowController(output: output, displays: displays)
    private let sleepGuard = SleepGuard()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = outputWindow
        sleepGuard.start()
        registerHotkeys()
        hotkeys.start()
        reopenLastProject()
    }

    /// Kein leeres Projekt und kein Öffnen-Dialog – stattdessen öffnet sich das letzte Projekt oder das Willkommensfenster.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    private func reopenLastProject() {
        guard let url = SessionStore.lastProjectURL, NSDocumentController.shared.documents.isEmpty else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }

    private func registerHotkeys() {
        hotkeys.register("b") { [output] in
            output.toggleBlack()
            return true
        }
        hotkeys.register(HotkeyService.space) { [output] in
            output.togglePause()
        }
        // Esc nur, wenn der Ausgang den Bildschirm des Steuerfensters blockiert.
        // Mit externem Bildschirm stoppt Esc nicht versehentlich – dafür gibt es den Notfall-Stopp ⌘.
        hotkeys.register(HotkeyService.escape) { [output, unowned self] in
            guard output.state.content != .idle, outputWindow.sharesControlScreen else { return false }
            output.stop()
            return true
        }
    }
}
