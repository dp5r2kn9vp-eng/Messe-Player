import Foundation

/// Was nach dem Ende eines Cues passiert („Danach“).
nonisolated enum FollowAction: String, Codable, CaseIterable {
    /// Halten: Bild bleibt stehen, Video geht auf Schwarz, nächster Cue nur per GO.
    case hold
    /// Weiter nach Ende: Nach Warten + Dauer startet der nächste Cue automatisch.
    case followOnEnd
    /// Mit nächstem starten: Der nächste Cue startet sofort zusammen mit diesem.
    case continueWithNext
}

/// Eine Zeile der Cue-Liste: ein Ereignis mit Nummer, Medium, Ausgang, Zeiten und Folgeaktion.
nonisolated struct Cue: Codable, Equatable, Identifiable {
    static let defaultStillDuration: TimeInterval = 5
    static let stillDurationRange: ClosedRange<TimeInterval> = 0.1...3600
    static let volumeRange: ClosedRange<Double> = 0...1

    let id: UUID
    /// Als String, damit Cues später eingefügt werden können („1.5“), ohne umzunummerieren.
    var number: String
    var name = ""
    /// `nil` = reiner Steuer-Cue.
    var mediumID: Medium.ID?
    /// `nil` bei Audio.
    var outputID: OutputDefinition.ID?
    /// Verzögerung vom Start bis zum Erscheinen des Inhalts.
    var wait: TimeInterval = 0
    var inPoint: TimeInterval = 0
    /// `nil` = bis Medienende.
    var outPoint: TimeInterval?
    /// Standdauer, nur für Bilder.
    var stillDuration: TimeInterval = Cue.defaultStillDuration {
        didSet { stillDuration = stillDuration.clamped(to: Self.stillDurationRange) }
    }
    var followAction = FollowAction.hold
    var volume = 1.0 {
        didSet { volume = volume.clamped(to: Self.volumeRange) }
    }
    var fadeIn: TimeInterval = 0
    var fadeOut: TimeInterval = 0
    var layers: [Layer] = []
    var notes = ""
    var color: RGBAColor?

    init(id: UUID = UUID(), number: String, mediumID: Medium.ID? = nil, outputID: OutputDefinition.ID? = nil) {
        self.id = id
        self.number = number
        self.mediumID = mediumID
        self.outputID = outputID
    }

    /// Fehlende Felder bekommen Standardwerte, damit Projekte ohne neuere Felder lesbar bleiben.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        number = try container.decode(String.self, forKey: .number)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        mediumID = try container.decodeIfPresent(UUID.self, forKey: .mediumID)
        outputID = try container.decodeIfPresent(UUID.self, forKey: .outputID)
        wait = try container.decodeIfPresent(TimeInterval.self, forKey: .wait) ?? 0
        inPoint = try container.decodeIfPresent(TimeInterval.self, forKey: .inPoint) ?? 0
        outPoint = try container.decodeIfPresent(TimeInterval.self, forKey: .outPoint)
        stillDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .stillDuration) ?? Self.defaultStillDuration
        followAction = try container.decodeIfPresent(FollowAction.self, forKey: .followAction) ?? .hold
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        fadeIn = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeIn) ?? 0
        fadeOut = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOut) ?? 0
        layers = try container.decodeIfPresent([Layer].self, forKey: .layers) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        color = try container.decodeIfPresent(RGBAColor.self, forKey: .color)
    }
}

/// Klammer um einen zusammenhängenden Bereich der Cue-Liste (kein Container).
nonisolated struct CueGroup: Codable, Equatable, Identifiable {
    enum Mode: Codable, Equatable {
        case loop
        /// Wiederholungen 1…99, danach greift „Danach“ des letzten Cues.
        case repeatCount(Int)
    }

    static let defaultCrossfade: TimeInterval = 0.5
    static let crossfadeRange: ClosedRange<TimeInterval> = 0...5
    static let repeatRange: ClosedRange<Int> = 1...99

    let id: UUID
    var name: String
    var firstCueID: Cue.ID
    var lastCueID: Cue.ID
    var mode = Mode.loop {
        didSet { if case .repeatCount(let count) = mode { mode = .repeatCount(count.clamped(to: Self.repeatRange)) } }
    }
    var crossfade: TimeInterval = CueGroup.defaultCrossfade {
        didSet { crossfade = crossfade.clamped(to: Self.crossfadeRange) }
    }
    var isCollapsed = false

    init(id: UUID = UUID(), name: String, firstCueID: Cue.ID, lastCueID: Cue.ID) {
        self.id = id
        self.name = name
        self.firstCueID = firstCueID
        self.lastCueID = lastCueID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        firstCueID = try container.decode(UUID.self, forKey: .firstCueID)
        lastCueID = try container.decode(UUID.self, forKey: .lastCueID)
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .loop
        crossfade = try container.decodeIfPresent(TimeInterval.self, forKey: .crossfade) ?? Self.defaultCrossfade
        isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed) ?? false
    }
}

/// Logischer Bildausgang („Ausgang 1“). Die Zuordnung zum Bildschirm liegt je Rechner, nicht im Projekt.
nonisolated struct OutputDefinition: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    static func numbered(_ number: Int) -> OutputDefinition {
        OutputDefinition(name: String(localized: "Ausgang \(number)"))
    }
}
