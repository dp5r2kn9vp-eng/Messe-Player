import SwiftUI

/// Rechte Leiste: Eigenschaften der in der Cue-Liste markierten Cues, nach Reitern geordnet.
/// Bei Mehrfachauswahl zeigt sie die Werte des ersten Cues und setzt Änderungen für alle.
struct InspectorPanel: View {
    @Binding var document: ProjectDocument
    let packageURL: URL?
    let selection: Set<UUID>

    @Environment(MediaLengths.self) private var mediaLengths
    @AppStorage("inspectorTab") private var chosenTab = InspectorTab.general

    private var project: Project { document.project }

    /// Markierte Cues in Listenreihenfolge (ein Gruppenkopf steht für seine Mitglieder).
    private var selectedCues: [Cue] {
        let ids = project.cueIDs(inSelection: selection)
        return project.cues.filter { ids.contains($0.id) }
    }

    var body: some View {
        let cues = selectedCues
        VStack(spacing: 0) {
            PanelHeader(title: "Inspektor", count: cues.count) { EmptyView() }
            Divider()
            if let primary = cues.first {
                content(primary: primary, cues: cues)
            } else {
                ContentUnavailableView("Kein Cue ausgewählt", systemImage: "sidebar.right", description: Text("Cue in der Liste markieren, um ihn hier zu bearbeiten."))
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func content(primary: Cue, cues: [Cue]) -> some View {
        let kinds = cues.map { $0.mediumID.flatMap(project.medium(withID:))?.kind }
        let tab = chosenTab.isApplicable(to: kinds) ? chosenTab : .general
        let model = document.rowModel(primary, mediaLength: document.mediaLength(of: primary, in: packageURL, lengths: mediaLengths))
        let context = InspectorContext(model: model, count: cues.count, isSound: InspectorTab.audio.isApplicable(to: kinds)) { edit in
            apply(edit, primary: primary.id, cues: cues)
        }
        return VStack(spacing: 0) {
            InspectorTabBar(selection: $chosenTab, current: tab, kinds: kinds)
            Divider()
            Form {
                Section(tab.title) { tabContent(tab, context: context) }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: InspectorTab, context: InspectorContext) -> some View {
        switch tab {
        case .general: InspectorGeneralTab(context: context, document: $document)
        case .timing: InspectorTimingTab(context: context)
        case .picture: InspectorPictureTab(context: context, group: groupBinding(of: context.model.cue))
        case .audio: InspectorAudioTab(context: context)
        case .trim: trimTab(context)
        case .layers: InspectorLayersTab(cue: $document.cue(context.model.cue.id), document: $document, packageURL: packageURL)
        }
    }

    private func trimTab(_ context: InspectorContext) -> some View {
        let url = context.model.medium.flatMap { document.media.url(for: $0, in: packageURL) }
        return InspectorTrimTab(context: context, url: url, mediaLength: mediaLengths.length(of: url))
            .id(context.cue.id)
    }

    private func groupBinding(of cue: Cue) -> Binding<CueGroup>? {
        project.group(containing: cue.id).map { $document.group($0.id) }
    }

    /// Mit Mehrfachauswahl gilt die Eingabe für alle markierten Cues – wie in der Listenzeile.
    private func apply(_ edit: CueEdit, primary: Cue.ID, cues: [Cue]) {
        let targets = edit.appliesToSelection ? Set(cues.map(\.id)) : [primary]
        document.project.apply(edit, to: targets) { cue in
            document.mediaLength(of: cue, in: packageURL, lengths: mediaLengths)
        }
    }
}

/// Was jeder Reiter braucht: Daten des ersten Cues, Größe der Auswahl und die Änderungsfunktion.
struct InspectorContext {
    let model: CueRowModel
    let count: Int
    /// Mindestens ein Cue mit Ton (Video oder Audio).
    let isSound: Bool
    let onEdit: (CueEdit) -> Void

    var cue: Cue { model.cue }
    var isMultiple: Bool { count > 1 }

    /// Bindung, die beim Setzen eine Änderung für die Auswahl auslöst.
    func binding<Value>(_ value: Value, _ edit: @escaping (Value) -> CueEdit) -> Binding<Value> {
        Binding(get: { value }, set: { onEdit(edit($0)) })
    }
}

/// Reiterleiste mit Symbolen; nicht zutreffende Reiter sind ausgegraut.
private struct InspectorTabBar: View {
    @Binding var selection: InspectorTab
    let current: InspectorTab
    let kinds: [Medium.Kind?]

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(InspectorTab.allCases) { tab in
                Button(tab.title, systemImage: tab.symbolName) { selection = tab }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, minHeight: Theme.minHitSize)
                    .foregroundStyle(tab == current ? Color.brandOrange : Color.primary)
                    .background(tab == current ? Color.brandOrange.opacity(0.15) : .clear, in: .rect(cornerRadius: Theme.Radius.button))
                    .disabled(!tab.isApplicable(to: kinds))
                    .help(Text(tab.title))
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
    }
}
