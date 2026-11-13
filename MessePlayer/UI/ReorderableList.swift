import SwiftUI
import UniformTypeIdentifiers

/// Sortierbare Liste mit Mehrfachauswahl, Entfernen (Löschtaste), Einfügen per Drag & Drop,
/// Kontextmenü und Hauptaktion (Doppelklick oder Return).
/// Gemeinsamer Baustein für Medienbibliothek und Gruppen.
struct ReorderableList<Item: Identifiable, Payload: Transferable, Row: View, Menu: View>: View {
    @Binding var items: [Item]
    @Binding var selection: Set<Item.ID>
    /// Eingefügte Objekte und die Zielposition in der Liste.
    let onInsert: ([Payload], Int) -> Void
    let primaryAction: (Set<Item.ID>) -> Void
    @ViewBuilder let menu: (Set<Item.ID>) -> Menu
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
        .contextMenu(forSelectionType: Item.ID.self, menu: menu, primaryAction: primaryAction)
        .onDeleteCommand { remove(selection) }
    }

    private func remove(_ ids: Set<Item.ID>) {
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
    }
}
