import SwiftUI

/// Hilfe-Fenster: Themen links, Inhalt rechts (feste Spalten statt Glas-Seitenleiste, damit es im CueView-Look bleibt). Die Tastenkürzel kommen aus `ShortcutInfo`.
struct HelpView: View {
    private static let shortcutsID = "tastenkuerzel"
    @State private var selection: String? = HelpTopic.all.first?.id

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(HelpTopic.all) { topic in
                    Text(topic.title).tag(Optional(topic.id))
                }
                Label("Tastenkürzel", systemImage: "keyboard").tag(Optional(Self.shortcutsID))
            }
            .scrollContentBackground(.hidden)
            .frame(width: 230)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    if selection == Self.shortcutsID {
                        Text("Tastenkürzel").font(.largeTitle.bold()).foregroundStyle(Color.brandPaper)
                        ShortcutList()
                    } else if let topic = HelpTopic.all.first(where: { $0.id == selection }) {
                        Text(topic.title).font(.largeTitle.bold()).foregroundStyle(Color.brandPaper)
                        HelpBlocksView(blocks: topic.blocks)
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.brandDark)
        .frame(minWidth: 820, minHeight: 520)
        .preferredColorScheme(.dark)
    }
}

/// Zeichnet Hilfeblöcke; Fettdruck im Text über Markdown.
struct HelpBlocksView: View {
    let blocks: [HelpBlock]

    var body: some View {
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            switch block {
            case .title(let text), .heading(let text):
                Text(markdown(text)).font(.title3.bold()).padding(.top, Theme.Spacing.s)
            case .bullet(let text):
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Circle().fill(Color.brandOrange).frame(width: 6, height: 6)
                    Text(markdown(text))
                }
            case .paragraph(let text):
                Text(markdown(text))
            }
        }
        .foregroundStyle(Color.brandPaper)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }

    private func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

/// Tabelle der Tastenkürzel.
struct ShortcutList: View {
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.l, verticalSpacing: Theme.Spacing.m) {
            ForEach(ShortcutInfo.all) { shortcut in
                GridRow {
                    Text(shortcut.keys)
                        .font(.body.monospaced().bold())
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Color.mutedDark.opacity(0.5)))
                    Text(shortcut.action)
                }
            }
        }
    }
}

/// Eigenes kleines Fenster mit allen Tastenkürzeln.
struct ShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Tastenkürzel").font(.title2.bold())
            ShortcutList()
            Text("Einzeltasten wirken nicht, während in einem Textfeld getippt wird.")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 560)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
    }
}
