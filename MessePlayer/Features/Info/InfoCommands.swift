import SwiftUI

/// Menüpunkte „Über CueView“ und das Hilfe-Menü.
struct InfoCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("Über CueView") { openWindow(id: WindowID.about) }
        }
        CommandGroup(replacing: .help) {
            Button("CueView-Hilfe") { openWindow(id: WindowID.help) }
                .keyboardShortcut("?", modifiers: .command)
            Button("Tastenkürzel") { openWindow(id: WindowID.shortcuts) }
                .keyboardShortcut("/", modifiers: .command)
            Divider()
            Button("Willkommensfenster") { openWindow(id: WindowID.welcome) }
        }
    }
}
