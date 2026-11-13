import AppKit
import Observation

/// Was das Ausgabefenster außer dem Inhalt wissen muss: ob es auf einem Bildschirm liegt und ob es sich kennzeichnet.
@Observable
final class OutputPresentation {
    /// `false`: Ausgang läuft als Vorschau im Steuerfenster, das Fenster rendert nichts (kein doppeltes Video).
    var isOnScreen = false
    /// Kennzeichnung („Ausgang 2“), solange sie eingeblendet ist.
    var identification: OutputIdentification?
}

struct OutputIdentification: Equatable {
    let name: String
    let colorIndex: Int
}

/// Ausgabefenster eines logischen Ausgangs: Vollbild auf dem zugeordneten Bildschirm.
/// Teilt es sich den Bildschirm mit dem Steuerfenster, erscheint es nur, während etwas läuft.
/// Fehlt der Bildschirm, bleibt das Fenster verborgen und der Ausgang läuft als Vorschau weiter.
@Observable
final class OutputWindowController {
    static let identificationDuration: Duration = .seconds(3)

    let outputID: OutputDefinition.ID
    let presentation = OutputPresentation()
    /// Der Ausgang liegt auf dem Bildschirm des Steuerfensters.
    private(set) var sharesControlScreen = false

    @ObservationIgnored private let engine: CueEngine
    @ObservationIgnored private let displays: DisplayService
    @ObservationIgnored private let routing: OutputRouting
    @ObservationIgnored private let window: NSWindow
    @ObservationIgnored private var isClosed = false
    @ObservationIgnored private var identificationTask: Task<Void, Never>?

    init(outputID: OutputDefinition.ID, engine: CueEngine, displays: DisplayService, routing: OutputRouting) {
        self.outputID = outputID
        self.engine = engine
        self.displays = displays
        self.routing = routing
        let contentView = OutputHostingView(rootView: OutputView(engine: engine, outputID: outputID, presentation: presentation))
        contentView.hidesCursor = true
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        // Über Menüleiste und Dock des Ausgabe-Bildschirms.
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        observe()
    }

    var isIdle: Bool {
        engine.state(for: outputID).content == .idle
    }

    /// Blendet den Ausgangsnamen für einige Sekunden auf dem Bildschirm ein (das Fenster folgt über `observe`).
    func identify(_ identification: OutputIdentification) {
        identificationTask?.cancel()
        presentation.identification = identification
        identificationTask = Task { [weak self] in
            try? await Task.sleep(for: Self.identificationDuration)
            guard !Task.isCancelled, let self else { return }
            presentation.identification = nil
        }
    }

    func close() {
        isClosed = true
        identificationTask?.cancel()
        window.orderOut(nil)
    }

    /// Reagiert auf Inhalt, Zuordnung und An-/Abstecken von Bildschirmen.
    private func observe() {
        withObservationTracking {
            apply()
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard !self.isClosed else { return }
                self.observe()
            }
        }
    }

    private func setSharesControlScreen(_ value: Bool) {
        if sharesControlScreen != value { sharesControlScreen = value }
    }

    private func apply() {
        let display = routing.display(for: outputID, in: displays.displays)
        if presentation.isOnScreen != (display != nil) {
            presentation.isOnScreen = display != nil
        }
        guard !isClosed, let display, let screen = displays.screen(for: display.id) else {
            setSharesControlScreen(false)
            window.orderOut(nil)
            return
        }
        setSharesControlScreen(displays.isControlScreen(screen))
        if sharesControlScreen && isIdle && presentation.identification == nil {
            window.orderOut(nil)
        } else {
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }
    }
}
