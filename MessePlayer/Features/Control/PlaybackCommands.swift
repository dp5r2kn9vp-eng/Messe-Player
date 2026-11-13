import SwiftUI

/// Menü „Wiedergabe“ mit dem Notfall-Stopp. ⌘. funktioniert immer, auch mit externem Bildschirm.
struct PlaybackCommands: Commands {
    let engine: CueEngine

    var body: some Commands {
        CommandMenu("Wiedergabe") {
            Button("Wiedergabe beenden", action: engine.stopAll)
                .keyboardShortcut(".", modifiers: .command)
        }
    }
}
