import SwiftUI

/// Leiste über dem Transport: je Ausgang Status, Black je Ausgang (nur auf externem Bildschirm) und – ohne Bildschirm – die Vorschau.
struct OutputsBar: View {
    @Environment(CueEngine.self) private var engine
    @Environment(OutputWindowManager.self) private var outputWindows

    /// Ab so vielen gleichzeitigen Videos warnt die Leiste vor Ruckeln.
    static let parallelVideoWarningLimit = 3

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            ForEach(Array(outputWindows.outputs.enumerated()), id: \.element.id) { index, output in
                OutputTile(
                    output: output,
                    colorIndex: index,
                    status: outputWindows.status(of: output.id),
                    offersBlack: outputWindows.showsOnExternalScreen(output.id)
                )
            }
            Spacer(minLength: 0)
            if engine.parallelVideoCount > Self.parallelVideoWarningLimit {
                Label("\(engine.parallelVideoCount) Videos gleichzeitig – Wiedergabe kann ruckeln", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandOrange)
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }
}

private struct OutputTile: View {
    let output: OutputDefinition
    let colorIndex: Int
    let status: OutputStatus
    let offersBlack: Bool

    @Environment(CueEngine.self) private var engine

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.s) {
                Circle().fill(Color.output(at: colorIndex)).frame(width: 10, height: 10)
                Text(output.name).font(.headline).lineLimit(1)
                if offersBlack {
                    BlackButton(isActive: engine.blackOutputIDs.contains(output.id), isCompact: true) {
                        engine.toggleBlack(output: output.id)
                    }
                    .help("Nur diesen Ausgang schwarz schalten (⇧B für den Ausgang am Abspielkopf)")
                }
            }
            statusLabel
            if status.isPreview {
                OutputView(engine: engine, outputID: output.id)
                    .frame(width: 192, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
                    .help("Vorschau: Dieser Ausgang hat keinen Bildschirm, die Show läuft hier weiter.")
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .screen(let name):
            Label(name, systemImage: "display").font(.caption).foregroundStyle(Color.mutedLight)
        case .preview:
            Label("Kein Bildschirm – Vorschau", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(Color.brandOrange)
        case .disconnected(let name):
            Label("„\(name)“ getrennt – Vorschau", systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(Color.brandRed)
        }
    }
}
