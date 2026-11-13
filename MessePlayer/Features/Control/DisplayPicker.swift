import SwiftUI

/// Auswahl, auf welchem Bildschirm der Ausgang im Vollbild läuft.
struct DisplayPicker: View {
    @Environment(OutputWindowController.self) private var outputWindow
    @Environment(DisplayService.self) private var displays

    var body: some View {
        @Bindable var outputWindow = outputWindow
        HStack(spacing: Theme.Spacing.s) {
            Picker("Ausgang", selection: $outputWindow.displayID) {
                ForEach(displays.displays) { display in
                    Text(display.name).tag(Optional(display.id))
                }
                if !outputWindow.isTargetConnected {
                    Text("Getrennt – wartet auf Bildschirm").tag(outputWindow.displayID)
                }
            }
            .frame(maxWidth: 320)
            if outputWindow.sharesControlScreen {
                Text("Steuerbildschirm: Vollbild beim Start · Esc beendet")
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
            }
        }
        .help("Bildschirm, auf dem der Ausgang im Vollbild läuft. Esc beendet Loop oder Einzelanzeige.")
    }
}
