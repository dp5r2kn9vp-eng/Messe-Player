import SwiftUI

/// Auswahl, auf welchem Bildschirm der Ausgang läuft.
struct DisplayPicker: View {
    @Environment(OutputWindowController.self) private var outputWindow
    @Environment(DisplayService.self) private var displays

    var body: some View {
        @Bindable var outputWindow = outputWindow
        Picker("Ausgang", selection: $outputWindow.target) {
            Text("Testfenster").tag(OutputTarget.window)
            ForEach(displays.externalDisplays) { display in
                Text(display.name).tag(OutputTarget.display(display.id))
            }
            if !outputWindow.isTargetConnected {
                Text("Getrennt – wartet auf Bildschirm").tag(outputWindow.target)
            }
        }
        .frame(maxWidth: 280)
    }
}
