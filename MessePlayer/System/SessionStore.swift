import Foundation

/// Was beim nächsten Start wiederhergestellt wird: Projekt, Ausgabezustand und Bildschirm.
struct SessionSnapshot: Codable, Equatable {
    enum Mode: Codable, Equatable {
        case idle
        case single(Medium.ID)
        case loop(MediaGroup.ID, Entry.ID?)
    }

    var projectPath: String?
    var mode = Mode.idle
    var isBlack = false
}

/// Speichert den Sitzungsstand in den Benutzereinstellungen.
enum SessionStore {
    private static let key = "session"
    private static let displayKey = "outputDisplayName"

    static func load(from defaults: UserDefaults = .standard) -> SessionSnapshot? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SessionSnapshot.self, from: $0) }
    }

    static func save(_ snapshot: SessionSnapshot, to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: key)
    }

    /// Zuletzt genutztes Projekt, falls es noch existiert.
    static var lastProjectURL: URL? {
        guard let path = load()?.projectPath, FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(filePath: path)
    }

    /// Name statt ID, weil sich Bildschirm-IDs nach einem Neustart ändern können.
    static var outputDisplayName: String? {
        get { UserDefaults.standard.string(forKey: displayKey) }
        set { UserDefaults.standard.set(newValue, forKey: displayKey) }
    }
}
