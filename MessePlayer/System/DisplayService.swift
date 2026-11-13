import AppKit
import Observation

/// Ein angeschlossener Bildschirm, stabil identifiziert über die CoreGraphics-ID.
nonisolated struct Display: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    /// Hardware-UUID; bleibt im Gegensatz zur ID über Neustarts gleich.
    var uuid: String?
    /// Bildschirm mit der Menüleiste – dort liegt das Steuerfenster.
    let isControlScreen: Bool

    var identity: ScreenIdentity {
        ScreenIdentity(uuid: uuid, name: name)
    }
}

/// Kennt die angeschlossenen Bildschirme; An- und Abstecken ändert `displays` (beobachtbar).
@Observable
final class DisplayService {
    private(set) var displays: [Display] = []

    @ObservationIgnored private var observation: Task<Void, Never>?

    init() {
        refresh()
        observation = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification)
            for await _ in changes {
                self?.refresh()
            }
        }
    }

    func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.displayID == id }
    }

    func isControlScreen(_ screen: NSScreen) -> Bool {
        screen == NSScreen.screens.first
    }

    private static func uuid(of id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
    }

    private func refresh() {
        displays = NSScreen.screens.enumerated().compactMap { index, screen in
            screen.displayID.map { id in
                Display(id: id, name: screen.localizedName, uuid: Self.uuid(of: id), isControlScreen: index == 0)
            }
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
