import SwiftUI
import UniformTypeIdentifiers

/// Sortierbare Liste mit Mehrfachauswahl, Entfernen (Löschtaste), Einfügen per Drag & Drop,
/// Kontextmenü und Hauptaktion (Doppelklick oder Return).
/// Gemeinsamer Baustein für Medienbibliothek und Cue-Liste.
struct ReorderableList<Item: Identifiable, Payload: Transferable, Row: View, Menu: View>: View {
    @Binding var items: [Item]
    @Binding var selection: Set<Item.ID>
    /// Eingefügte Objekte und die Zielposition in der Liste.
    let onInsert: ([Payload], Int) -> Void
    let onRemove: (Set<Item.ID>) -> Void
    /// Eigenes Verschieben (z. B. wenn Zeilen nur eine Sicht auf das Modell sind); Standard: `items` umsortieren.
    var onMove: ((IndexSet, Int) -> Void)?
    let primaryAction: (Set<Item.ID>) -> Void
    @ViewBuilder let menu: (Set<Item.ID>) -> Menu
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        List(selection: $selection) {
            ForEach(items) { item in
                row(item).tag(item.id)
            }
            .onMove { offsets, destination in
                if let onMove {
                    onMove(offsets, destination)
                } else {
                    items.move(fromOffsets: offsets, toOffset: destination)
                }
            }
            .dropDestination(for: Payload.self) { payloads, index in
                onInsert(payloads, index)
            }
        }
        .contextMenu(forSelectionType: Item.ID.self, menu: menu, primaryAction: primaryAction)
        .onDeleteCommand { onRemove(selection) }
    }
}
