import SwiftUI
import UniformTypeIdentifiers

/// Sortierbare Liste mit Mehrfachauswahl, Entfernen (Löschtaste) und Einfügen per Drag & Drop.
/// Gemeinsamer Baustein für Medienbibliothek und Gruppen.
struct ReorderableList<Item: Identifiable, Payload: Transferable, Row: View>: View {
    @Binding var items: [Item]
    @Binding var selection: Set<Item.ID>
    /// Eingefügte Objekte und die Zielposition in der Liste.
    let onInsert: ([Payload], Int) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                row(item).tag(item.id)
            }
            .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            .dropDestination(for: Payload.self) { payloads, index in
                onInsert(payloads, index)
            }
        }
        .onDeleteCommand(perform: removeSelection)
    }

    private func removeSelection() {
        items.removeAll { selection.contains($0.id) }
        selection.removeAll()
    }
}
