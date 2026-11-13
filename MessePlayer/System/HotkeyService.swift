import AppKit

/// Ein-Tasten-Kürzel ohne Modifier (z. B. „B“ für Black, Esc für Stopp).
/// Greift nicht, solange ein Textfeld aktiv ist. Liefert eine Aktion `false`, behält die Taste ihre normale Funktion.
final class HotkeyService {
    static let escape = "\u{1b}"

    private var actions: [String: () -> Bool] = [:]
    private var monitor: Any?

    func register(_ key: String, action: @escaping () -> Bool) {
        actions[key.lowercased()] = action
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            let modifiers = event.modifierFlags
            let handled = MainActor.assumeIsolated { self?.handle(key: key, modifiers: modifiers) ?? false }
            return handled ? nil : event
        }
    }

    private func handle(key: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        let relevantModifiers = modifiers.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        guard relevantModifiers.isEmpty,
              !(NSApp.keyWindow?.firstResponder is NSText),
              let key,
              let action = actions[key]
        else { return false }
        return action()
    }
}
