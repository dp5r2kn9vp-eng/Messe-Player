import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension FocusedValues {
    /// Speicherort des Projekts im aktiven Fenster; `nil`, solange es nie gespeichert wurde.
    @Entry var projectPackageURL: URL?
}

/// Menüpunkte „Projekt exportieren …“ und „Projekt importieren …“ im Ablage-Menü.
struct ArchiveCommands: Commands {
    @FocusedValue(\.projectPackageURL) private var packageURL

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Projekt als Zip exportieren …") { exportProject() }
                .disabled(packageURL == nil)
            Button("Projekt aus Zip importieren …") { importProject() }
        }
    }

    private func exportProject() {
        guard let packageURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = packageURL.deletingPathExtension().lastPathComponent + ".zip"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        perform { try ProjectArchive.export(package: packageURL, to: destination) }
    }

    private func importProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let archive = panel.url else { return }
        perform {
            let package = try ProjectArchive.importArchive(archive, into: archive.deletingLastPathComponent())
            NSDocumentController.shared.openDocument(withContentsOf: package, display: true) { _, _, error in
                if let error { NSAlert(error: error).runModal() }
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
