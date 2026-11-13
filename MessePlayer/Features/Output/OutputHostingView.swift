import AppKit
import SwiftUI

/// Blendet den Mauszeiger über dem Ausgang aus, damit am Fernseher nichts stört.
final class OutputHostingView: NSHostingView<OutputView> {
    var hidesCursor = false {
        didSet { if !hidesCursor { showCursor() } }
    }

    private var isCursorHidden = false
    private var cursorArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let cursorArea { removeTrackingArea(cursorArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        cursorArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard hidesCursor, !isCursorHidden else { return }
        NSCursor.hide()
        isCursorHidden = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        showCursor()
    }

    private func showCursor() {
        guard isCursorHidden else { return }
        NSCursor.unhide()
        isCursorHidden = false
    }
}
