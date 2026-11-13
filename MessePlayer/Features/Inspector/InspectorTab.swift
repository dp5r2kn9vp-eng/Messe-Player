import SwiftUI

/// Reiter des Inspektors. Nicht zutreffende Reiter sind für die Auswahl ausgegraut.
nonisolated enum InspectorTab: String, CaseIterable, Identifiable {
    case general
    case timing
    case picture
    case audio
    case trim
    case layers

    var id: Self { self }

    /// Bei Mehrfachauswahl genügt ein passender Cue; Änderungen überspringen die übrigen.
    /// `kinds` enthält je ausgewähltem Cue die Medienart (`nil` = Steuer-Cue oder Medium fehlt).
    func isApplicable(to kinds: [Medium.Kind?]) -> Bool {
        guard !kinds.isEmpty else { return false }
        let visual = kinds.contains { $0 == .image || $0 == .video }
        let sound = kinds.contains { $0 == .video || $0 == .audio }
        switch self {
        case .general, .timing: return true
        case .picture: return visual
        case .audio, .trim: return sound
        // Der Ebenen-Editor bearbeitet genau einen Cue mit Bild.
        case .layers: return kinds.count == 1 && visual
        }
    }
}

extension InspectorTab {
    var title: LocalizedStringKey {
        switch self {
        case .general: "Allgemein"
        case .timing: "Zeit & Ablauf"
        case .picture: "Ausgang & Bild"
        case .audio: "Audio"
        case .trim: "Trim"
        case .layers: "Texte & Ebenen"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "info.circle"
        case .timing: "clock"
        case .picture: "display"
        case .audio: "speaker.wave.2"
        case .trim: "scissors"
        case .layers: "textformat"
        }
    }
}

extension ContentScaling {
    var title: LocalizedStringKey {
        switch self {
        case .fit: "Einpassen"
        case .fill: "Füllen"
        }
    }
}
