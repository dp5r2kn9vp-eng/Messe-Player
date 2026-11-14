import Foundation

/// Minimale HTTP/1.1-Anfrage (nur, was die Fernsteuerung braucht).
nonisolated struct HTTPRequest: Equatable {
    let method: String
    let path: String
    /// Kopfzeilen mit kleingeschriebenem Namen.
    let headers: [String: String]
    let body: Data

    static let maxSize = 64 * 1024

    enum ParseResult: Equatable {
        case incomplete
        case invalid
        case request(HTTPRequest, consumed: Int)
    }

    /// Liest eine Anfrage vom Anfang von `data`.
    static func parse(_ data: Data) -> ParseResult {
        guard let headerEnd = data.firstRange(of: Data("\r\n\r\n".utf8)) else {
            return data.count > maxSize ? .invalid : .incomplete
        }
        guard let head = String(data: data[data.startIndex..<headerEnd.lowerBound], encoding: .utf8) else { return .invalid }
        var lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.removeFirst().split(separator: " ")
        guard requestLine.count == 3, requestLine[2].hasPrefix("HTTP/1.") else { return .invalid }
        var headers: [String: String] = [:]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { return .invalid }
            headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = headers["content-length"].flatMap(Int.init) ?? 0
        guard length >= 0, length <= maxSize else { return .invalid }
        let bodyStart = headerEnd.upperBound
        guard data.distance(from: bodyStart, to: data.endIndex) >= length else { return .incomplete }
        let bodyEnd = data.index(bodyStart, offsetBy: length)
        let path = String(requestLine[1]).components(separatedBy: "?")[0]
        let request = HTTPRequest(method: String(requestLine[0]), path: path, headers: headers, body: Data(data[bodyStart..<bodyEnd]))
        return .request(request, consumed: data.distance(from: data.startIndex, to: bodyEnd))
    }

    /// Token aus `Authorization: Bearer …`.
    var bearerToken: String? {
        guard let value = headers["authorization"], value.lowercased().hasPrefix("bearer ") else { return nil }
        return String(value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }
}

nonisolated struct HTTPResponse: Equatable {
    let status: Int
    var body = Data()
    var contentType = "application/json; charset=utf-8"

    static func json(_ value: some Encodable, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, body: (try? RemoteAPI.encoder.encode(value)) ?? Data())
    }

    static func error(_ status: Int, _ message: String) -> HTTPResponse {
        json(["error": message], status: status)
    }

    /// Antwort samt Kopfzeilen; die Verbindung schließt danach.
    var serialized: Data {
        var head = "HTTP/1.1 \(status) \(Self.reason(status))\r\n"
        head += "Content-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        return Data(head.utf8) + body
    }

    private static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 429: "Too Many Requests"
        default: "Error"
        }
    }
}
