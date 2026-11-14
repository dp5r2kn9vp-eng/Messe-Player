import AppKit

/// Nachfrage vor dem Beenden, damit der Ausgang am Stand nicht versehentlich schwarz wird.
enum QuitConfirmation {
    /// `true`, wenn beendet werden darf. Beim Abmelden, Neustarten oder Ausschalten fragt CueView nicht.
    static func confirm(isOutputActive: Bool) -> Bool {
        guard !isSystemQuit else { return true }
        let alert = NSAlert()
        alert.messageText = String(localized: "CueView wirklich beenden?")
        alert.informativeText = isOutputActive
            ? String(localized: "Auf dem Ausgang läuft gerade Inhalt. Beim Beenden wird der Bildschirm sofort leer.")
            : String(localized: "Alle Ausgänge werden geschlossen.")
        alert.alertStyle = isOutputActive ? .critical : .warning
        alert.addButton(withTitle: String(localized: "Beenden"))
        alert.addButton(withTitle: String(localized: "Abbrechen"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Das System schickt beim Abmelden/Ausschalten einen Beenden-Befehl mit Grund mit.
    private static var isSystemQuit: Bool {
        NSAppleEventManager.shared().currentAppleEvent?.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
    }
}
