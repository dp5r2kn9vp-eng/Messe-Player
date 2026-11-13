import Foundation

/// Was beim nächsten Start wiederhergestellt wird: Projekt, Ausgabezustand und Bildschirm.
struct SessionSnapshot: Codable, Equatable {
    var projectPath: String?
    /// Cues, deren Inhalt auf einem Ausgang zu sehen war.
    var visibleCueIDs: [Cue.ID] = []
    var playheadID: Cue.ID?
    var isBlack = false
    /// Ausgänge mit eigenem Black (⇧B).
    var blackOutputIDs: [OutputDefinition.ID] = []
}

extension SessionSnapshot {
    /// Ältere Schnappschüsse (Gruppen-Loop) behalten Projekt und Black; der Ausgang startet im Ruhezustand.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        visibleCueIDs = try container.decodeIfPresent([Cue.ID].self, forKey: .visibleCueIDs) ?? []
        playheadID = try container.decodeIfPresent(Cue.ID.self, forKey: .playheadID)
        isBlack = try container.decodeIfPresent(Bool.self, forKey: .isBlack) ?? false
        blackOutputIDs = try container.decodeIfPresent([OutputDefinition.ID].self, forKey: .blackOutputIDs) ?? []
    }
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

    /// Bildschirm des einen Ausgangs aus CueView vor 2.0; Vorschlag für den ersten Ausgang ohne Zuordnung.
    static func legacyOutputDisplayName(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: displayKey)
    }
}
