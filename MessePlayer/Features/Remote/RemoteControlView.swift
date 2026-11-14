import SwiftUI

/// Fenster „Fernsteuerung“: ein-/ausschalten, PIN zum Koppeln, gekoppelte Geräte.
struct RemoteControlView: View {
    @Environment(RemoteServer.self) private var server
    @Environment(RemotePairing.self) private var pairing
    @AppStorage(TransportSettings.remoteEnabledKey) private var isEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("Fernsteuerung im lokalen Netz", isOn: $isEnabled)
                statusRow
            } footer: {
                Text("Aus = kein offener Port. macOS fragt beim ersten Einschalten nach dem lokalen Netzwerk und eingehenden Verbindungen – beides erlauben.")
                    .foregroundStyle(Color.mutedLight)
            }
            if isEnabled { pinSection }
            devicesSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .frame(minHeight: 420)
        .onChange(of: isEnabled, initial: true) { _, enabled in
            enabled ? server.start() : server.stop()
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch server.status {
        case .off:
            Label("Aus", systemImage: "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(Color.mutedLight)
        case .starting:
            Label("Startet …", systemImage: "antenna.radiowaves.left.and.right")
        case .running(let httpPort, _):
            LabeledContent("Erreichbar unter") {
                Text(verbatim: "\(ProcessInfo.processInfo.hostName):\(httpPort)")
                    .textSelection(.enabled)
                    .monospaced()
            }
            LabeledContent("Verbunden") {
                Text("\(server.connectedCount) Gerät(e)")
            }
        case .failed(let message):
            Label("Fehler: \(message)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.brandRed)
        }
    }

    private var pinSection: some View {
        Section("Neues Gerät koppeln") {
            LabeledContent("PIN") {
                HStack(spacing: Theme.Spacing.m) {
                    Text(verbatim: pairing.pin)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.brandOrange)
                    Button("Neue PIN", systemImage: "arrow.clockwise", action: pairing.renewPIN)
                        .labelStyle(.iconOnly)
                        .help("Neue PIN erzeugen")
                }
            }
            Text("In „CueView Remote“ auf dem iPad diesen Mac wählen und die PIN eingeben. Nach jeder Kopplung gilt eine neue PIN.")
                .font(.callout)
                .foregroundStyle(Color.mutedLight)
        }
    }

    private var devicesSection: some View {
        Section("Gekoppelte Geräte") {
            if pairing.devices.isEmpty {
                Text("Noch keine").foregroundStyle(Color.mutedLight)
            }
            ForEach(pairing.devices) { device in
                HStack {
                    VStack(alignment: .leading) {
                        Text(device.name)
                        Text(device.pairedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color.mutedLight)
                    }
                    Spacer()
                    Button("Entfernen", systemImage: "trash", role: .destructive) { remove(device) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help("Gerät entfernen – es muss sich neu koppeln")
                }
            }
        }
    }

    /// Entfernt das Gerät und trennt alle Live-Verbindungen; gekoppelte Geräte verbinden sich neu.
    private func remove(_ device: PairedDevice) {
        pairing.remove(device.id)
        server.disconnectAll()
    }
}

/// Kleine Anzeige in der Transportleiste, solange die Fernsteuerung läuft.
struct RemoteStatusBadge: View {
    @Environment(RemoteServer.self) private var server
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if server.isRunning {
            Button {
                openWindow(id: WindowID.remote)
            } label: {
                Label("\(server.connectedCount)", systemImage: "antenna.radiowaves.left.and.right")
                    .monospacedDigit()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(server.connectedCount > 0 ? Color.brandOrange : Color.mutedLight)
            .help("Fernsteuerung an – \(server.connectedCount) Gerät(e) verbunden")
        }
    }
}
