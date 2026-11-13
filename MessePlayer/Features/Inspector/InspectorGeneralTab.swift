import SwiftUI
import UniformTypeIdentifiers

/// Allgemein: Nummer, Name, Notiz, Farbe, Medium ersetzen bzw. neu verknüpfen.
struct InspectorGeneralTab: View {
    let context: InspectorContext
    @Binding var document: ProjectDocument

    @State private var isPickingFile = false
    @State private var importErrors: [String] = []

    var body: some View {
        let cue = context.cue
        TextField("Nummer", text: context.binding(cue.number, CueEdit.number))
            .disabled(context.isMultiple)
        TextField("Name", text: context.binding(cue.name, CueEdit.name), prompt: Text(context.model.displayName))
            .disabled(context.isMultiple)
        TextField("Notiz", text: context.binding(cue.notes, CueEdit.notes), axis: .vertical)
            .lineLimit(2...6)
        LabeledContent("Farbe") {
            HStack(spacing: Theme.Spacing.s) {
                ColorPicker("Farbe", selection: color, supportsOpacity: false)
                    .labelsHidden()
                Button("Keine", systemImage: "xmark.circle") { context.onEdit(.color(nil)) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(cue.color == nil)
                    .help("Farbe entfernen")
            }
        }
        LabeledContent("Medium") {
            mediumMenu
        }
        .importErrorAlert($importErrors)
        .fileImporter(isPresented: $isPickingFile, allowedContentTypes: [.image, .movie]) { result in
            if case .success(let url) = result { relink(to: url) }
        }
    }

    private var color: Binding<Color> {
        Binding(
            get: { context.cue.color.map { Color($0) } ?? .brandOrange },
            set: { context.onEdit(.color(RGBAColor($0))) }
        )
    }

    private var mediumMenu: some View {
        Menu {
            ForEach(document.project.media) { medium in
                Button(medium.displayName, systemImage: medium.kind.symbolName) { context.onEdit(.medium(medium.id)) }
            }
            Divider()
            Button("Datei wählen …", systemImage: "folder") { isPickingFile = true }
        } label: {
            Label(mediumTitle, systemImage: context.model.isMissing ? "exclamationmark.triangle.fill" : "photo.on.rectangle")
        }
        .disabled(context.isMultiple)
        .help(context.isMultiple ? "Medium nur bei einem Cue ersetzen" : "Medium ersetzen oder fehlende Datei neu verknüpfen")
    }

    private var mediumTitle: String {
        if let medium = context.model.medium { return medium.displayName }
        return context.cue.mediumID == nil ? String(localized: "Steuer-Cue") : String(localized: "Medium fehlt")
    }

    /// Nimmt die Datei in den Medienbereich auf und setzt sie als Medium des Cues.
    private func relink(to url: URL) {
        let result = document.importMedia(from: [url], at: document.project.media.count)
        importErrors = result.errors.map(\.localizedDescription)
        if let medium = result.added.first { context.onEdit(.medium(medium.id)) }
    }
}
