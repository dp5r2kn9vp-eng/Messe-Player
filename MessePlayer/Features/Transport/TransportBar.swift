import SwiftUI

/// Transportleiste unten im Steuerfenster: GO, Als Nächstes, Pause, Stopp alle, Black.
/// Im Messe-Modus nur GO, Stopp und Black.
struct TransportBar: View {
    /// Lädt die Cue-Liste dieses Fensters in die Engine, bevor gestartet wird.
    let claim: () -> Void
    var isTradeShowMode = false

    @Environment(CueEngine.self) private var engine
    @Environment(\.cueNames) private var cueNames
    @AppStorage(TransportSettings.keyChangeNoticeKey) private var didAcknowledgeKeyChange = false

    var body: some View {
        VStack(spacing: 0) {
            if !didAcknowledgeKeyChange { keyChangeNotice }
            controls
        }
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button {
                claim()
                engine.go()
            } label: {
                Text("GO")
                    .font(.title2.weight(.bold))
                    .frame(minWidth: 88, minHeight: Theme.minHitSize + Theme.Spacing.s)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandOrange)
            .disabled(engine.playheadID == nil)
            .help("Cue am Abspielkopf starten (Leertaste)")
            nextCueLabel
            Spacer()
            if !isTradeShowMode { pauseButton }
            Button("Stopp alle", systemImage: "stop.fill", action: engine.stopAll)
                .help("Alle Cues beenden, der Abspielkopf bleibt (⌘. Notfall-Stopp)")
            BlackAllButton()
        }
        .padding(Theme.Spacing.m)
    }

    private var pauseButton: some View {
        Button(engine.isPaused ? "Fortsetzen" : "Pause", systemImage: engine.isPaused ? "play.fill" : "pause.fill") {
            engine.togglePause()
        }
        .disabled(engine.running.isEmpty)
        .help("Alle laufenden Cues anhalten bzw. fortsetzen (P)")
    }

    /// Einmaliger Hinweis auf die geänderte Belegung von Leertaste und P.
    private var keyChangeNotice: some View {
        HStack(spacing: Theme.Spacing.m) {
            Label("Neue Tasten: **Leertaste = GO**, **P = Pause/Fortsetzen**. B, Esc und ⌘. bleiben wie bisher.", systemImage: "keyboard")
                .font(.callout)
            Spacer()
            Button("Verstanden") { didAcknowledgeKeyChange = true }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .background(Color.brandOrange.opacity(0.2))
    }

    private var nextCueLabel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Als Nächstes").font(.caption).foregroundStyle(Color.mutedLight)
            Text(engine.playheadID.map(cueNames) ?? String(localized: "Ende der Liste"))
                .font(.headline)
                .lineLimit(1)
            if let missing = engine.missingCueID {
                Label("Cue \(cueNames(missing)): Medium fehlt", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandRed)
            }
        }
    }
}

extension EnvironmentValues {
    /// Anzeigename eines Cues („2 Intro-Film“), gesetzt vom Steuerfenster.
    @Entry var cueNames: (Cue.ID) -> String = { _ in "" }
}
