import Foundation
import Network
import Observation

/// Fernsteuer-Server im lokalen Netz: HTTP für Befehle, WebSocket für den Live-Zustand, Bonjour `_cueview._tcp`.
/// Läuft nur, solange er gestartet ist (ausgeschaltet = kein offener Port). Alles auf der Hauptwarteschlange.
@Observable
final class RemoteServer {
    static let serviceType = "_cueview._tcp"
    static let defaultHTTPPort: NWEndpoint.Port = 7520
    static let defaultWebSocketPort: NWEndpoint.Port = 7521
    /// Abstand, in dem der Zustand auf Änderungen geprüft wird (Ziel: Meldung unter 200 ms).
    static let statePollInterval: TimeInterval = 0.1

    enum Status: Equatable {
        case off
        case starting
        case running(httpPort: UInt16, webSocketPort: UInt16)
        case failed(String)
    }

    private(set) var status = Status.off
    /// Offene WebSocket-Verbindungen (verbundene Geräte).
    private(set) var connectedCount = 0

    @ObservationIgnored private let router: RemoteRouter
    @ObservationIgnored private let pairing: RemotePairing
    @ObservationIgnored private let state: () -> RemoteState
    @ObservationIgnored private var httpListener: NWListener?
    @ObservationIgnored private var socketListener: NWListener?
    @ObservationIgnored private var sockets: [ObjectIdentifier: NWConnection] = [:]
    @ObservationIgnored private var lastSent: RemoteState?
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var loopbackOnly = false

    init(router: RemoteRouter, pairing: RemotePairing, state: @escaping () -> RemoteState) {
        self.router = router
        self.pairing = pairing
        self.state = state
    }

    var isRunning: Bool {
        if case .running = status { true } else { false }
    }

    // MARK: Start/Stopp

    /// `loopbackOnly` (Tests): nur auf diesem Rechner erreichbar, ohne Bonjour.
    func start(httpPort: NWEndpoint.Port = defaultHTTPPort, webSocketPort: NWEndpoint.Port = defaultWebSocketPort, loopbackOnly: Bool = false) {
        guard status == .off || isFailed else { return }
        status = .starting
        self.loopbackOnly = loopbackOnly
        let advertises = !loopbackOnly
        do {
            let socketListener = try NWListener(using: restricted(webSocketParameters()), on: webSocketPort)
            self.socketListener = socketListener
            socketListener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(socket: connection) }
            }
            socketListener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated { self?.socketListenerChanged(state, httpPort: httpPort, advertises: advertises) }
            }
            socketListener.start(queue: .main)
        } catch {
            fail(error)
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        httpListener?.cancel()
        socketListener?.cancel()
        httpListener = nil
        socketListener = nil
        disconnectAll()
        lastSent = nil
        status = .off
    }

    /// Trennt alle Geräte (z. B. nach dem Entfernen eines Geräts); gekoppelte verbinden sich neu.
    func disconnectAll() {
        sockets.values.forEach { $0.cancel() }
        sockets = [:]
        connectedCount = 0
    }

    private var isFailed: Bool {
        if case .failed = status { true } else { false }
    }

    private func fail(_ error: Error) {
        stop()
        status = .failed(error.localizedDescription)
    }

    private func socketListenerChanged(_ state: NWListener.State, httpPort: NWEndpoint.Port, advertises: Bool) {
        switch state {
        case .ready:
            guard httpListener == nil, let socketPort = socketListener?.port else { return }
            startHTTP(on: httpPort, socketPort: socketPort, advertises: advertises)
        case .failed(let error):
            fail(error)
        default:
            break
        }
    }

    private func startHTTP(on port: NWEndpoint.Port, socketPort: NWEndpoint.Port, advertises: Bool) {
        do {
            let listener = try NWListener(using: restricted(.tcp), on: port)
            if advertises {
                let txt = NWTXTRecord(["v": String(RemoteAPI.version), "ws": String(socketPort.rawValue)])
                listener.service = NWListener.Service(name: Host.current().localizedName, type: Self.serviceType, txtRecord: txt)
            }
            listener.newConnectionHandler = { [weak self] connection in
                MainActor.assumeIsolated { self?.accept(http: connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.status = .running(httpPort: listener.port?.rawValue ?? 0, webSocketPort: socketPort.rawValue)
                        self.startPolling()
                    case .failed(let error):
                        self.fail(error)
                    default:
                        break
                    }
                }
            }
            httpListener = listener
            listener.start(queue: .main)
        } catch {
            fail(error)
        }
    }

    private func restricted(_ parameters: NWParameters) -> NWParameters {
        if loopbackOnly { parameters.requiredInterfaceType = .loopback }
        return parameters
    }

    // MARK: HTTP

    private func accept(http connection: NWConnection) {
        connection.start(queue: .main)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: HTTPRequest.maxSize) { [weak self] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                let buffer = buffer + (data ?? Data())
                switch HTTPRequest.parse(buffer) {
                case .request(let request, _):
                    self.respond(self.router.handle(request), on: connection)
                case .invalid:
                    self.respond(.error(400, "Ungültige Anfrage"), on: connection)
                case .incomplete:
                    if isComplete || error != nil {
                        connection.cancel()
                    } else {
                        self.receiveRequest(on: connection, buffer: buffer)
                    }
                }
            }
        }
    }

    private func respond(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.serialized, completion: .contentProcessed { _ in connection.cancel() })
        // Befehle ändern den Zustand: sofort an die Geräte melden.
        broadcastIfChanged()
    }

    // MARK: WebSocket

    /// Nur gekoppelte Geräte (`Authorization: Bearer …`) dürfen sich verbinden.
    private func webSocketParameters() -> NWParameters {
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        options.setClientRequestHandler(.main) { [weak self] _, headers in
            let authorized = MainActor.assumeIsolated {
                let values = Dictionary(headers.map { ($0.name.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
                let request = HTTPRequest(method: "GET", path: "/events", headers: values, body: Data())
                return self?.router.isAuthorized(request) ?? false
            }
            return NWProtocolWebSocket.Response(status: authorized ? .accept : .reject, subprotocol: nil)
        }
        let parameters = NWParameters.tcp
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        return parameters
    }

    private func accept(socket connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self else { return }
                switch state {
                case .ready:
                    self.sockets[id] = connection
                    self.connectedCount = self.sockets.count
                    self.send(self.state(), to: connection)
                case .failed, .cancelled:
                    self.sockets[id] = nil
                    self.connectedCount = self.sockets.count
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        receiveMessages(on: connection)
    }

    /// Nachrichten des Geräts werden ignoriert; das Lesen erkennt nur das Schließen.
    private func receiveMessages(on connection: NWConnection) {
        connection.receiveMessage { [weak self] _, _, isComplete, error in
            MainActor.assumeIsolated {
                if error != nil || (isComplete && connection.state != .ready) {
                    connection.cancel()
                } else {
                    self?.receiveMessages(on: connection)
                }
            }
        }
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.statePollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.broadcastIfChanged() }
        }
    }

    private func broadcastIfChanged() {
        guard !sockets.isEmpty else { return }
        let current = state()
        guard current != lastSent else { return }
        lastSent = current
        sockets.values.forEach { send(current, to: $0) }
    }

    private func send(_ state: RemoteState, to connection: NWConnection) {
        guard let data = try? RemoteAPI.encoder.encode(state) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "state", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }
}
