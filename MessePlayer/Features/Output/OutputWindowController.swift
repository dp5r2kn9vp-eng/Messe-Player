import AppKit
import Observation

/// Wohin der Ausgang gerendert wird.
enum OutputTarget: Hashable {
    /// Normales Fenster auf dem Laptop – zum Testen ohne Fernseher.
    case window
    case display(CGDirectDisplayID)
}

/// Verwaltet das eine Ausgabefenster und platziert es auf dem gewählten Ziel.
@Observable
final class OutputWindowController {
    var target: OutputTarget {
        didSet { apply() }
    }

    /// `false`, wenn der gewählte Bildschirm abgesteckt ist; der Ausgang wartet dann auf ihn.
    private(set) var isTargetConnected = true

    @ObservationIgnored private let displays: DisplayService
    @ObservationIgnored private let contentView: OutputHostingView
    @ObservationIgnored private let window: NSWindow

    init(output: OutputController, displays: DisplayService) {
        self.displays = displays
        target = displays.externalDisplays.first.map { .display($0.id) } ?? .window
        contentView = OutputHostingView(rootView: OutputView(output: output))
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        displays.onChange = { [weak self] in self?.displaysChanged() }
        apply()
    }

    private func displaysChanged() {
        guard case .display = target else { return }
        apply()
    }

    private func apply() {
        switch target {
        case .window:
            isTargetConnected = true
            showAsWindow()
        case .display(let id):
            guard let screen = displays.screen(for: id) else {
                // Nicht aufs Laptop springen, sondern warten, bis der Bildschirm wieder da ist.
                isTargetConnected = false
                window.orderOut(nil)
                return
            }
            isTargetConnected = true
            showFullScreen(on: screen)
        }
    }

    private func showFullScreen(on screen: NSScreen) {
        window.styleMask = [.borderless]
        // Über Menüleiste und Dock des Ausgabe-Bildschirms.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.setFrame(screen.frame, display: true)
        contentView.hidesCursor = true
        window.orderFrontRegardless()
    }

    private func showAsWindow() {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.level = .normal
        window.collectionBehavior = []
        window.title = String(localized: "Ausgang (Testfenster)")
        contentView.hidesCursor = false
        window.setContentSize(NSSize(width: 960, height: 540))
        window.contentAspectRatio = NSSize(width: 16, height: 9)
        window.center()
        window.orderFront(nil)
    }
}
