import Foundation
import Network
import Testing
@testable import MessePlayer

struct HTTPRequestTests {
    @Test func parsesRequestWithBodyAndBearer() throws {
        let raw = "POST /playhead?x=1 HTTP/1.1\r\nHost: a\r\nAuthorization: Bearer abc\r\nContent-Length: 2\r\n\r\n{}"
        guard case .request(let request, let consumed) = HTTPRequest.parse(Data(raw.utf8)) else {
            Issue.record("keine Anfrage")
            return
        }
        #expect(request.method == "POST" && request.path == "/playhead")
        #expect(request.bearerToken == "abc")
        #expect(request.body == Data("{}".utf8))
        #expect(consumed == raw.utf8.count)
    }

    @Test func waitsForCompleteBody() {
        let raw = "POST /go HTTP/1.1\r\nContent-Length: 10\r\n\r\n{}"
        #expect(HTTPRequest.parse(Data(raw.utf8)) == .incomplete)
        #expect(HTTPRequest.parse(Data("GET /state HTTP/1.1\r\n".utf8)) == .incomplete)
    }

    @Test func rejectsGarbage() {
        #expect(HTTPRequest.parse(Data("hallo\r\n\r\n".utf8)) == .invalid)
    }
}

struct RemotePairingTests {
    let defaults = UserDefaults(suiteName: "RemotePairingTests-\(UUID())") ?? .standard

    @Test func correctPINIssuesTokenAndRenewsPIN() throws {
        var pins = ["1234", "5678"]
        let pairing = RemotePairing(defaults: defaults, makePIN: { pins.removeFirst() })
        let device = try pairing.pair(pin: "1234", deviceName: " iPad Stand ").get()
        #expect(device.name == "iPad Stand")
        #expect(device.token.count == 64)
        #expect(pairing.device(forToken: device.token) == device)
        #expect(pairing.pin == "5678")
        #expect(RemotePairing(defaults: defaults).devices == [device])
    }

    @Test func locksAfterTooManyWrongPINs() {
        let clock = VirtualClock()
        let pairing = RemotePairing(defaults: defaults, now: { clock.now }, makePIN: { "0000" })
        for _ in 1..<RemotePairing.maxFailedAttempts {
            #expect(pairing.pair(pin: "9999", deviceName: "x") == .failure(.wrongPIN))
        }
        #expect(pairing.pair(pin: "9999", deviceName: "x") == .failure(.wrongPIN))
        guard case .failure(.locked) = pairing.pair(pin: "0000", deviceName: "x") else {
            Issue.record("nicht gesperrt")
            return
        }
        clock.advance(by: RemotePairing.lockDuration)
        #expect((try? pairing.pair(pin: "0000", deviceName: "x").get()) != nil)
    }

    @Test func removedDeviceLosesAccess() throws {
        let pairing = RemotePairing(defaults: defaults, makePIN: { "1111" })
        let device = try pairing.pair(pin: "1111", deviceName: "x").get()
        pairing.remove(device.id)
        #expect(pairing.device(forToken: device.token) == nil)
    }
}

@MainActor
struct RemoteRouterTests {
    let clock = VirtualClock()
    let engine: CueEngine
    let pairing: RemotePairing
    let router: RemoteRouter

    init() {
        let clock = clock
        let engine = CueEngine(scheduler: clock, now: { clock.now }, audio: RecordingAudioOutput())
        let pairing = RemotePairing(defaults: UserDefaults(suiteName: "RemoteRouterTests-\(UUID())") ?? .standard, makePIN: { "4321" })
        self.engine = engine
        self.pairing = pairing
        router = RemoteRouter(engine: engine, pairing: pairing) { RemoteState(engine: engine, timetable: nil, isTradeShowMode: false) }
    }

    private func request(_ method: String, _ path: String, token: String? = nil, body: String = "") -> HTTPRequest {
        HTTPRequest(method: method, path: path, headers: token.map { ["authorization": "Bearer \($0)"] } ?? [:], body: Data(body.utf8))
    }

    private func pairedToken() throws -> String {
        let response = router.handle(request("POST", "/pair", body: #"{"pin":"4321","deviceName":"iPad"}"#))
        #expect(response.status == 200)
        let json = try #require(try JSONSerialization.jsonObject(with: response.body) as? [String: Any])
        return try #require(json["token"] as? String)
    }

    @Test func everythingButPairNeedsToken() {
        #expect(router.handle(request("GET", "/state")).status == 401)
        #expect(router.handle(request("POST", "/go", token: "falsch")).status == 401)
        #expect(router.handle(request("POST", "/pair", body: #"{"pin":"0000"}"#)).status == 403)
        #expect(router.handle(request("POST", "/pair", body: "kaputt")).status == 400)
    }

    @Test func goStartsCueAndReturnsState() throws {
        let cues = [ShowFixture.cue(.image), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        let token = try pairedToken()
        let response = router.handle(request("POST", "/go", token: token))
        #expect(response.status == 200)
        let state = try RemoteAPI.decoder.decode(RemoteState.self, from: response.body)
        #expect(state.running.map(\.cue.id) == [cues[0].id])
        #expect(state.running.first?.duration == 5)
        #expect(state.playhead?.id == cues[1].id)
    }

    @Test func blackPlayheadAndEndLoopCommands() throws {
        let cues = (0..<3).map { _ in ShowFixture.cue(.image) }
        engine.load(ShowFixture.show(cues, groups: [(0...1, .loop)]))
        let token = try pairedToken()
        #expect(router.handle(request("POST", "/black/\(ShowFixture.outputA1)", token: token)).status == 404)
        #expect(router.handle(request("POST", "/black", token: token)).status == 200)
        #expect(engine.isBlack)
        #expect(router.handle(request("POST", "/playhead", token: token, body: #"{"offset":2}"#)).status == 200)
        #expect(engine.playheadID == cues[2].id)
        #expect(router.handle(request("POST", "/playhead", token: token, body: #"{"cueID":"\#(cues[0].id)"}"#)).status == 200)
        router.handle(request("POST", "/go", token: token))
        #expect(router.handle(request("POST", "/end-loop", token: token, body: #"{"after":"cue"}"#)).status == 200)
        #expect(engine.loopEnding(of: engine.show.groups[0].id) == .afterCue)
        #expect(router.handle(request("POST", "/unbekannt", token: token)).status == 404)
        #expect(router.handle(request("DELETE", "/go", token: token)).status == 405)
    }

    @Test func cueListHasNumbersTitlesAndKinds() throws {
        var cue = ShowFixture.cue(.video)
        cue.number = "7"
        cue.title = "Präsentation"
        engine.load(ShowFixture.show([cue]))
        let token = try pairedToken()
        let list = try RemoteAPI.decoder.decode([RemoteCue].self, from: router.handle(request("GET", "/cues", token: token)).body)
        #expect(list == [RemoteCue(id: cue.id, number: "7", title: "Präsentation", kind: "video", groupID: nil)])
    }
}

/// Echter Server auf dem Loopback-Interface: Kopplung per HTTP, Zustand per WebSocket.
@MainActor
struct RemoteServerIntegrationTests {
    @Test func pairCommandAndLiveStateOverSockets() async throws {
        let engine = CueEngine(audio: RecordingAudioOutput())
        let cues = [ShowFixture.cue(.image, duration: 60), ShowFixture.cue(.image)]
        engine.load(ShowFixture.show(cues))
        let pairing = RemotePairing(defaults: UserDefaults(suiteName: "RemoteServerTests-\(UUID())") ?? .standard, makePIN: { "2468" })
        let state = { RemoteState(engine: engine, timetable: nil, isTradeShowMode: false) }
        let server = RemoteServer(router: RemoteRouter(engine: engine, pairing: pairing, state: state), pairing: pairing, state: state)
        server.start(httpPort: .any, webSocketPort: .any, loopbackOnly: true)
        defer { server.stop() }

        var ports: (UInt16, UInt16)?
        for _ in 0..<100 {
            if case .running(let http, let socket) = server.status { ports = (http, socket); break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let (httpPort, socketPort) = try #require(ports)
        let base = try #require(URL(string: "http://127.0.0.1:\(httpPort)"))

        var unauthorized = URLRequest(url: base.appending(path: "state"))
        unauthorized.httpMethod = "GET"
        let (_, denied) = try await URLSession.shared.data(for: unauthorized)
        #expect((denied as? HTTPURLResponse)?.statusCode == 401)

        var pair = URLRequest(url: base.appending(path: "pair"))
        pair.httpMethod = "POST"
        pair.httpBody = Data(#"{"pin":"2468","deviceName":"Test"}"#.utf8)
        let (pairData, _) = try await URLSession.shared.data(for: pair)
        let token = try #require((try JSONSerialization.jsonObject(with: pairData) as? [String: Any])?["token"] as? String)

        var socketRequest = URLRequest(url: try #require(URL(string: "ws://127.0.0.1:\(socketPort)/events")))
        socketRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let socket = URLSession.shared.webSocketTask(with: socketRequest)
        socket.resume()
        defer { socket.cancel() }
        let initial = try await receiveState(socket)
        #expect(initial.running.isEmpty)

        var go = URLRequest(url: base.appending(path: "go"))
        go.httpMethod = "POST"
        go.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let started = Date()
        _ = try await URLSession.shared.data(for: go)
        let live = try await receiveState(socket)
        #expect(live.running.map(\.cue.id) == [cues[0].id])
        #expect(Date().timeIntervalSince(started) < 1)
        #expect(server.connectedCount == 1)
    }

    @Test func stoppedServerClosesPorts() async throws {
        let engine = CueEngine(audio: RecordingAudioOutput())
        let pairing = RemotePairing(defaults: UserDefaults(suiteName: "RemoteServerTests-\(UUID())") ?? .standard)
        let state = { RemoteState(engine: engine, timetable: nil, isTradeShowMode: false) }
        let server = RemoteServer(router: RemoteRouter(engine: engine, pairing: pairing, state: state), pairing: pairing, state: state)
        #expect(server.status == .off)
        server.start(httpPort: .any, webSocketPort: .any, loopbackOnly: true)
        var httpPort: UInt16?
        for _ in 0..<100 {
            if case .running(let http, _) = server.status { httpPort = http; break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let port = try #require(httpPort)
        server.stop()
        #expect(server.status == .off)
        try await Task.sleep(for: .milliseconds(100))
        let url = try #require(URL(string: "http://127.0.0.1:\(port)/state"))
        await #expect(throws: (any Error).self) { try await URLSession.shared.data(from: url) }
    }

    private func receiveState(_ socket: URLSessionWebSocketTask) async throws -> RemoteState {
        guard case .string(let text) = try await socket.receive() else {
            throw URLError(.cannotParseResponse)
        }
        return try RemoteAPI.decoder.decode(RemoteState.self, from: Data(text.utf8))
    }
}
