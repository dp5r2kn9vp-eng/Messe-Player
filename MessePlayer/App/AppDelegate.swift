import AppKit

/// Hält die app-weiten Dienste. Es gibt genau einen Ausgang, unabhängig davon, welche Projekte offen sind.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let output = OutputController()
    let displays = DisplayService()
    private(set) lazy var outputWindow = OutputWindowController(output: output, displays: displays)
    private let hotkeys = HotkeyService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = outputWindow
        hotkeys.register("b") { [output] in
            output.toggleBlack()
            return true
        }
        hotkeys.register(HotkeyService.escape) { [output] in
            guard output.state.content != .idle else { return false }
            output.stop()
            return true
        }
        hotkeys.start()
    }
}
