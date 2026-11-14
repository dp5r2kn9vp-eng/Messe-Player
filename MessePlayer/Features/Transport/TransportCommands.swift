import SwiftUI

/// Gespeicherte Einstellungen rund um den Transport.
enum TransportSettings {
    /// Messe-Modus: gesperrte Liste, nur GO/Stopp/Black sichtbar.
    static let tradeShowModeKey = "isTradeShowMode"
    /// Der einmalige Hinweis auf die geänderten Tasten (Leertaste/P) wurde bestätigt.
    static let keyChangeNoticeKey = "didAcknowledgeKeyChange"
    /// Zeitplan auch außerhalb des Messe-Modus aktiv.
    static let scheduleActiveKey = "isScheduleActive"

    /// Uhrzeit-Starts gelten im Messe-Modus oder mit „Zeitplan aktiv“.
    static func isScheduleEnabled() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: tradeShowModeKey) || defaults.bool(forKey: scheduleActiveKey)
    }
}

/// Menü „Wiedergabe“: Transport, Notfall-Stopp und Messe-Modus.
/// Die Ein-Tasten-Kürzel (Leertaste, P, B, ⇧B, L, ⇧L, Esc) laufen über `HotkeyService`, damit sie in Textfeldern nicht greifen.
/// ⌘. funktioniert immer, auch mit externem Bildschirm.
struct TransportCommands: Commands {
    let engine: CueEngine

    @AppStorage(TransportSettings.tradeShowModeKey) private var isTradeShowMode = false
    @AppStorage(TransportSettings.scheduleActiveKey) private var isScheduleActive = false

    var body: some Commands {
        CommandMenu("Wiedergabe") {
            Button("GO (Leertaste)", action: engine.go)
                .disabled(engine.playheadID == nil)
            Button(engine.isPaused ? "Fortsetzen (P)" : "Pause (P)") { engine.togglePause() }
                .disabled(engine.running.isEmpty)
            Button("Loop beenden (L)") { engine.endLoop(.afterPass) }
                .disabled(engine.loopTargets.isEmpty)
            Button("Loop nach aktuellem Cue beenden (⇧L)") { engine.endLoop(.afterCue) }
                .disabled(engine.loopTargets.isEmpty)
            Button("Stopp alle", action: engine.stopAll)
            Button("Black alle (B)", action: engine.toggleBlack)
            Divider()
            Button("Wiedergabe beenden", action: engine.emergencyStop)
                .keyboardShortcut(".", modifiers: .command)
            Divider()
            Toggle("Messe-Modus", isOn: $isTradeShowMode)
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Toggle("Zeitplan aktiv", isOn: $isScheduleActive)
                .help("Cues mit Uhrzeit starten auch außerhalb des Messe-Modus")
        }
    }
}
