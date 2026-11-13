import AppKit
import Observation

/// Ein-Tasten-Kürzel ohne Modifier oder nur mit Umschalt (z. B. „B“ Black alle, „⇧B“ Black je Ausgang).
/// Greift nicht, solange ein Textfeld aktiv ist. Liefert eine Aktion `false`, behält die Taste ihre normale Funktion.
@Observable
final class HotkeyService {
    static let escape = "\u{1b}"
    static let space = " "

    @ObservationIgnored private var actions: [String: () -> Bool] = [:]
    @ObservationIgnored private var monitor: Any?

    func register(_ key: String, shift: Bool = false, action: @escaping () -> Bool) {
        actions[Self.id(key, shift: shift)] = action
    }

    private static func id(_ key: String, shift: Bool) -> String {
        (shift ? "⇧" : "") + key.lowercased()
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
        guard relevantModifiers.subtracting(.shift).isEmpty,
              !(NSApp.keyWindow?.firstResponder is NSText),
              let key,
              let action = actions[Self.id(key, shift: relevantModifiers.contains(.shift))]
        else { return false }
        return action()
    }
}
