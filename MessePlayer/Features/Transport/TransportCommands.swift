import SwiftUI

/// Gespeicherte Einstellungen rund um den Transport.
enum TransportSettings {
    /// Messe-Modus: gesperrte Liste, nur GO/Stopp/Black sichtbar.
    static let tradeShowModeKey = "isTradeShowMode"
    /// Der einmalige Hinweis auf die geänderten Tasten (Leertaste/P) wurde bestätigt.
    static let keyChangeNoticeKey = "didAcknowledgeKeyChange"
}

/// Menü „Wiedergabe“: Transport, Notfall-Stopp und Messe-Modus.
/// Die Ein-Tasten-Kürzel (Leertaste, P, B, ⇧B, Esc) laufen über `HotkeyService`, damit sie in Textfeldern nicht greifen.
/// ⌘. funktioniert immer, auch mit externem Bildschirm.
struct TransportCommands: Commands {
    let engine: CueEngine

    @AppStorage(TransportSettings.tradeShowModeKey) private var isTradeShowMode = false

    var body: some Commands {
        CommandMenu("Wiedergabe") {
            Button("GO (Leertaste)", action: engine.go)
                .disabled(engine.playheadID == nil)
            Button(engine.isPaused ? "Fortsetzen (P)" : "Pause (P)") { engine.togglePause() }
                .disabled(engine.running.isEmpty)
            Button("Stopp alle", action: engine.stopAll)
            Button("Black alle (B)", action: engine.toggleBlack)
            Divider()
            Button("Wiedergabe beenden", action: engine.emergencyStop)
                .keyboardShortcut(".", modifiers: .command)
            Divider()
            Toggle("Messe-Modus", isOn: $isTradeShowMode)
                .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }
}
