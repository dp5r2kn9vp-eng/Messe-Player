import SwiftUI

extension View {
    /// Meldet Dateien, die beim Import übersprungen wurden.
    func importErrorAlert(_ messages: Binding<[String]>) -> some View {
        alert(
            "Nicht alle Dateien wurden übernommen",
            isPresented: Binding(get: { !messages.wrappedValue.isEmpty }, set: { if !$0 { messages.wrappedValue = [] } })
        ) {
            Button("OK") {}
        } message: {
            Text(messages.wrappedValue.joined(separator: "\n"))
        }
    }
}
