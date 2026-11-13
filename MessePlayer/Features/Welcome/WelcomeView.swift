import AppKit
import SwiftUI

/// Willkommensfenster beim Start: neues Projekt, öffnen, zuletzt geöffnet, Beispiel, Hilfe.
/// Schließt sich selbst, sobald ein Projekt offen ist.
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var errorMessage: String?
    /// Erst beim Erscheinen laden: Ein früher Zugriff auf `NSDocumentController.shared`
    /// legt den Controller an, bevor SwiftUI seinen eigenen einrichtet – das führt zum Absturz beim Start.
    @State private var recent: [URL] = []

    var body: some View {
        HStack(spacing: 0) {
            actions
            Divider()
            recentProjects
        }
        .frame(width: 760, height: 440)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
        .task {
            recent = NSDocumentController.shared.recentDocumentURLs
            await closeWhenProjectOpens()
        }
        .alert("Beispielprojekt konnte nicht angelegt werden", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.m) {
            AppIconImage(size: 96)
            CueViewWordmark(height: 56)
            Text("Version \(AppInfo.version)").font(.caption).foregroundStyle(Color.mutedLight)
            Spacer().frame(height: Theme.Spacing.s)
            WelcomeButton(title: "Neues Projekt", symbol: "plus.rectangle") {
                NSDocumentController.shared.newDocument(nil)
            }
            WelcomeButton(title: "Projekt öffnen …", symbol: "folder") {
                NSDocumentController.shared.openDocument(nil)
            }
            WelcomeButton(title: "Beispielprojekt öffnen", symbol: "sparkles", action: openSample)
            WelcomeButton(title: "Hilfe", symbol: "questionmark.circle") {
                openWindow(id: WindowID.help)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 320)
    }

    private var recentProjects: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Zuletzt geöffnet").font(.headline).padding(.horizontal, Theme.Spacing.l)
            if recent.isEmpty {
                ContentUnavailableView("Noch keine Projekte", systemImage: "doc", description: Text("Lege ein neues Projekt an oder öffne das Beispiel."))
            } else {
                List(recent, id: \.self) { url in
                    Button { open(url) } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(url.deletingPathExtension().lastPathComponent).foregroundStyle(Color.brandPaper)
                            Text(url.deletingLastPathComponent().path(percentEncoded: false))
                                .font(.caption)
                                .foregroundStyle(Color.mutedLight)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.vertical, Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSAlert(error: error).runModal() }
        }
    }

    private func openSample() {
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            open(try SampleProject.ensure(in: folder))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Wird beim Start das letzte Projekt wiederhergestellt oder eins geöffnet, verschwindet das Fenster.
    private func closeWhenProjectOpens() async {
        if SessionStore.lastProjectURL != nil {
            dismissWindow()
            return
        }
        while !Task.isCancelled {
            if !NSDocumentController.shared.documents.isEmpty {
                dismissWindow()
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

private struct WelcomeButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .controlSize(.large)
    }
}
