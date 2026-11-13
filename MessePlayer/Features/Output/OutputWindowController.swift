import AppKit
import Observation

/// Verwaltet das eine Ausgabefenster: immer Vollbild auf dem gewählten Bildschirm.
/// Teilt sich der Ausgang den Bildschirm mit dem Steuerfenster, erscheint er nur, während etwas läuft.
@Observable
final class OutputWindowController {
    var displayID: CGDirectDisplayID? {
        didSet { apply() }
    }

    /// `false`, wenn der gewählte Bildschirm abgesteckt ist; der Ausgang wartet dann auf ihn.
    private(set) var isTargetConnected = true
    /// Der Ausgang liegt auf dem Bildschirm des Steuerfensters.
    private(set) var sharesControlScreen = false

    @ObservationIgnored private let output: OutputController
    @ObservationIgnored private let displays: DisplayService
    @ObservationIgnored private let contentView: OutputHostingView
    @ObservationIgnored private let window: NSWindow

    init(output: OutputController, displays: DisplayService) {
        self.output = output
        self.displays = displays
        displayID = displays.preferredOutput?.id
        contentView = OutputHostingView(rootView: OutputView(output: output))
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        // Über Menüleiste und Dock des Ausgabe-Bildschirms.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        contentView.hidesCursor = true
        displays.onChange = { [weak self] in self?.apply() }
        observeOutput()
        apply()
    }

    private func observeOutput() {
        withObservationTracking {
            _ = output.state.content
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.apply()
                self.observeOutput()
            }
        }
    }

    private func apply() {
        guard let displayID, let screen = displays.screen(for: displayID) else {
            // Nicht auf einen anderen Bildschirm springen, sondern warten, bis der gewählte wieder da ist.
            isTargetConnected = displayID == nil
            window.orderOut(nil)
            return
        }
        isTargetConnected = true
        sharesControlScreen = displays.isControlScreen(screen)
        if sharesControlScreen && output.state.content == .idle {
            window.orderOut(nil)
        } else {
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }
    }
}
