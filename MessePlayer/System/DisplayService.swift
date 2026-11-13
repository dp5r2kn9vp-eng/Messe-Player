import AppKit
import Observation

/// Ein angeschlossener Bildschirm, stabil identifiziert über die CoreGraphics-ID.
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    /// Bildschirm mit der Menüleiste – dort liegt das Steuerfenster.
    let isControlScreen: Bool
}

/// Kennt die angeschlossenen Bildschirme und meldet An- und Abstecken.
@Observable
final class DisplayService {
    private(set) var displays: [Display] = []

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var observation: Task<Void, Never>?

    init() {
        refresh()
        observation = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification)
            for await _ in changes {
                self?.refresh()
                self?.onChange?()
            }
        }
    }

    /// Bevorzugter Ausgang: der erste externe Bildschirm, sonst der eigene.
    var preferredOutput: Display? {
        displays.first { !$0.isControlScreen } ?? displays.first
    }

    func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == id }
    }

    func isControlScreen(_ screen: NSScreen) -> Bool {
        screen == NSScreen.screens.first
    }

    private func refresh() {
        displays = NSScreen.screens.enumerated().compactMap { index, screen in
            screen.displayID.map { Display(id: $0, name: screen.localizedName, isControlScreen: index == 0) }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
