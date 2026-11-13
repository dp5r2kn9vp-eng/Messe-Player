import SwiftUI

/// Ausgänge des Projekts anlegen/umbenennen und auf diesem Rechner Bildschirmen zuordnen.
/// Die Zuordnung liegt in den Benutzereinstellungen, nicht im Projekt.
struct OutputSetupSheet: View {
    @Binding var project: Project

    @Environment(OutputRouting.self) private var routing
    @Environment(DisplayService.self) private var displays
    @Environment(OutputWindowManager.self) private var outputWindows
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Ausgänge").font(.title2.weight(.semibold))
            Text("Die Bildschirm-Zuordnung gilt nur für diesen Rechner und steht nicht in der Projektdatei. Ausgänge ohne Bildschirm laufen als Vorschau im Steuerfenster.")
                .font(.callout)
                .foregroundStyle(Color.mutedLight)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.s) {
                ForEach(Array(project.outputs.enumerated()), id: \.element.id) { index, output in
                    row(output, colorIndex: index)
                }
            }
            Text("Esc beendet die Wiedergabe nur, wenn ein Ausgang auf dem Steuerbildschirm liegt; ⌘. immer.")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
            HStack {
                Button("Ausgang hinzufügen", systemImage: "plus") { addOutput() }
                Button("Bildschirme kennzeichnen", systemImage: "number.square") { outputWindows.identifyScreens() }
                    .help("Blendet auf jedem zugeordneten Bildschirm den Namen seines Ausgangs ein")
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 620)
    }

    private func row(_ output: OutputDefinition, colorIndex: Int) -> some View {
        GridRow {
            Circle().fill(Color.output(at: colorIndex)).frame(width: 12, height: 12)
            TextField("Name", text: Binding(get: { output.name }, set: { project.renameOutput(output.id, to: $0) }))
                .frame(width: 180)
            Picker("Bildschirm", selection: screenBinding(for: output.id)) {
                Text("Vorschau im Steuerfenster").tag(ScreenIdentity?.none)
                ForEach(displays.displays) { display in
                    Text(display.isControlScreen ? "\(display.name) (Steuerbildschirm)" : display.name)
                        .tag(ScreenIdentity?.some(display.identity))
                }
                if case .disconnected(let name) = outputWindows.status(of: output.id) {
                    Text("\(name) – getrennt").tag(routing.assignment(for: output.id)?.screen)
                }
            }
            .labelsHidden()
            .frame(width: 280)
            Button("Entfernen", systemImage: "trash") { project.removeOutput(output.id) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!project.canRemoveOutput)
                .help("Ausgang entfernen; seine Cues wechseln auf den ersten Ausgang")
        }
    }

    /// Angeschlossene Bildschirme werden über ihre aktuelle Identität angezeigt, damit die Auswahl passt.
    private func screenBinding(for outputID: OutputDefinition.ID) -> Binding<ScreenIdentity?> {
        Binding(
            get: {
                let screen = routing.assignment(for: outputID)?.screen
                return screen?.match(in: displays.displays)?.identity ?? screen
            },
            set: { routing.assign(outputID, to: $0) }
        )
    }

    private func addOutput() {
        let id = project.addOutput()
        routing.assign(id, to: nil)
    }
}
