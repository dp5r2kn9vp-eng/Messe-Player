import Foundation

/// Ein Block der Hilfetexte. Die Hilfe nutzt bewusst nur dieses kleine Markdown-Format.
enum HelpBlock: Equatable {
    case title(String)
    case heading(String)
    case bullet(String)
    case paragraph(String)

    /// Zerlegt Markdown in Blöcke: `# Titel`, `## Überschrift`, `- Punkt`, sonst Absatz.
    static func parse(_ markdown: String) -> [HelpBlock] {
        markdown.split(separator: "\n", omittingEmptySubsequences: true).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
            if line.hasPrefix("# ") { return .title(String(line.dropFirst(2))) }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            return .paragraph(line)
        }
    }
}

/// Ein Hilfethema aus einer Datei `hilfe-*.md` im App-Bundle.
struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let blocks: [HelpBlock]

    static func == (lhs: HelpTopic, rhs: HelpTopic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(id: String, markdown: String) {
        self.id = id
        let blocks = HelpBlock.parse(markdown)
        title = blocks.compactMap { if case .title(let text) = $0 { text } else { nil } }.first ?? id
        self.blocks = blocks.filter { if case .title = $0 { false } else { true } }
    }

    /// Alle Themen, sortiert nach Dateiname.
    static let all: [HelpTopic] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("hilfe-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                (try? String(contentsOf: url, encoding: .utf8)).map {
                    HelpTopic(id: url.deletingPathExtension().lastPathComponent, markdown: $0)
                }
            }
    }()
}

/// Alle Tastenkürzel – eine Quelle für Hilfe und Übersichtsfenster.
struct ShortcutInfo: Identifiable {
    let keys: String
    let action: String
    var id: String { keys }

    static let all = [
        ShortcutInfo(keys: "B", action: String(localized: "Black: Ausgang sofort schwarz, nochmal drücken zeigt wieder das Bild")),
        ShortcutInfo(keys: String(localized: "Leertaste"), action: String(localized: "Pause / Weiter")),
        ShortcutInfo(keys: "⌘.", action: String(localized: "Notfall-Stopp: beendet die Wiedergabe immer")),
        ShortcutInfo(keys: "Esc", action: String(localized: "Wiedergabe beenden – nur wenn der Ausgang auf dem Steuerbildschirm liegt")),
        ShortcutInfo(keys: "1–9", action: String(localized: "Gruppe 1–9 starten")),
        ShortcutInfo(keys: String(localized: "Doppelklick / Return"), action: String(localized: "Medium auf dem Ausgang zeigen bzw. Loop ab diesem Eintrag starten")),
        ShortcutInfo(keys: "⌘S", action: String(localized: "Projekt speichern")),
        ShortcutInfo(keys: "⌘?", action: String(localized: "Hilfe öffnen")),
    ]
}
