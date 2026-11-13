import SwiftUI

/// Menü „Wiedergabe“ mit dem Notfall-Stopp. ⌘. funktioniert immer, auch mit externem Bildschirm.
struct PlaybackCommands: Commands {
    let output: OutputController

    var body: some Commands {
        CommandMenu("Wiedergabe") {
            Button("Wiedergabe beenden", action: output.stop)
                .keyboardShortcut(".", modifiers: .command)
        }
    }
}
