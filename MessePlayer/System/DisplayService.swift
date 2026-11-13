import AppKit
import Observation

/// Ein angeschlossener Bildschirm, stabil identifiziert über die CoreGraphics-ID.
struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
}

/// Kennt die angeschlossenen Bildschirme und meldet An- und Abstecken.
@Observable
final class DisplayService {
    /// Alle Bildschirme außer dem mit der Menüleiste – dort liegt das Steuerfenster.
    private(set) var externalDisplays: [Display] = []

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

    func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == id }
    }

    private func refresh() {
        externalDisplays = NSScreen.screens.dropFirst().compactMap { screen in
            screen.displayID.map { Display(id: $0, name: screen.localizedName) }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
