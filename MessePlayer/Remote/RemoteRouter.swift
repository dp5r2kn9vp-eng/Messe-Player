import Foundation

/// Verarbeitet Anfragen der Fernsteuerung ohne Netz: Kopplung, Token-Prüfung, Befehle an die Engine.
/// Befehle wirken wie in CueView selbst, auch im Messe-Modus.
final class RemoteRouter {
    private struct PairRequest: Decodable {
        let pin: String
        let deviceName: String?
    }

    private struct PairResponse: Encodable {
        let token: String
        let deviceID: UUID
        let apiVersion: Int
    }

    private struct EndLoopRequest: Decodable {
        /// `pass` (Standard) oder `cue`.
        let after: String?
    }

    private struct PlayheadRequest: Decodable {
        let cueID: UUID?
        let offset: Int?
    }

    private let engine: CueEngine
    private let pairing: RemotePairing
    private let state: () -> RemoteState

    init(engine: CueEngine, pairing: RemotePairing, state: @escaping () -> RemoteState) {
        self.engine = engine
        self.pairing = pairing
        self.state = state
    }

    func handle(_ request: HTTPRequest) -> HTTPResponse {
        if request.path == "/pair" {
            return request.method == "POST" ? pair(request) : .error(405, "POST erwartet")
        }
        guard isAuthorized(request) else { return .error(401, "Gerät nicht gekoppelt") }
        switch (request.method, request.path) {
        case ("GET", "/state"): return .json(state())
        case ("GET", "/cues"): return .json(RemoteCue.list(of: engine.show))
        case ("POST", let path): return command(path, body: request.body)
        case ("GET", _): return .error(404, "Unbekannter Pfad")
        default: return .error(405, "Methode nicht erlaubt")
        }
    }

    func isAuthorized(_ request: HTTPRequest) -> Bool {
        request.bearerToken.flatMap(pairing.device(forToken:)) != nil
    }

    private func pair(_ request: HTTPRequest) -> HTTPResponse {
        guard let body = try? RemoteAPI.decoder.decode(PairRequest.self, from: request.body) else {
            return .error(400, "pin fehlt")
        }
        switch pairing.pair(pin: body.pin, deviceName: body.deviceName ?? "") {
        case .success(let device):
            return .json(PairResponse(token: device.token, deviceID: device.id, apiVersion: RemoteAPI.version))
        case .failure(.wrongPIN):
            return .error(403, "Falsche PIN")
        case .failure(.locked):
            return .error(429, "Zu viele Versuche, bitte kurz warten")
        }
    }

    private func command(_ path: String, body: Data) -> HTTPResponse {
        switch path {
        case "/go": engine.go()
        case "/stop": engine.stopAll()
        case "/emergency": engine.emergencyStop()
        case "/pause": engine.togglePause()
        case "/black": engine.toggleBlack()
        case "/end-loop":
            let after = (try? RemoteAPI.decoder.decode(EndLoopRequest.self, from: body))?.after
            engine.endLoop(after == "cue" ? .afterCue : .afterPass)
        case "/playhead":
            guard let move = try? RemoteAPI.decoder.decode(PlayheadRequest.self, from: body) else { return .error(400, "cueID oder offset fehlt") }
            if let cueID = move.cueID {
                guard engine.show.index(of: cueID) != nil else { return .error(404, "Cue nicht gefunden") }
                engine.setPlayhead(cueID)
            } else if let offset = move.offset {
                engine.movePlayhead(by: offset)
            } else {
                return .error(400, "cueID oder offset fehlt")
            }
        default:
            guard path.hasPrefix("/black/"), let id = UUID(uuidString: String(path.dropFirst(7))) else {
                return .error(404, "Unbekannter Befehl")
            }
            guard engine.show.outputs.contains(where: { $0.id == id }) else { return .error(404, "Ausgang nicht gefunden") }
            engine.toggleBlack(output: id)
        }
        return .json(state())
    }
}
