import CoreTransferable
import UniformTypeIdentifiers

nonisolated extension UTType {
    /// Verweis auf ein Medium des Projekts beim Ziehen aus dem Medienbereich (nur innerhalb der App).
    static let cueViewMedium = UTType(exportedAs: "de.klangniveau.cueview.medium-reference")
}

/// Ein Medium des Medienbereichs als Drag-Inhalt.
nonisolated struct MediumReference: Codable, Transferable {
    let id: Medium.ID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cueViewMedium)
    }
}

/// Was in der Cue-Liste abgelegt werden kann: ein Medium aus dem Medienbereich oder eine Datei aus dem Finder.
nonisolated enum CueListDrop: Transferable {
    case medium(Medium.ID)
    case file(URL)

    private struct NotExportable: Error {}

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation<CueListDrop, MediumReference>(exporting: { drop in
            guard case .medium(let id) = drop else { throw NotExportable() }
            return MediumReference(id: id)
        }, importing: { .medium($0.id) })
        ProxyRepresentation<CueListDrop, URL>(exporting: { drop in
            guard case .file(let url) = drop else { throw NotExportable() }
            return url
        }, importing: { .file($0) })
    }
}
