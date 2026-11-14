import AppKit
import SwiftUI

/// Willkommensfenster beim Start: fortsetzen, neues Projekt, öffnen, zuletzt geöffnet, Beispiel, Hilfe und Hinweise.
/// Schließt sich selbst, sobald ein Projekt offen ist.
struct WelcomeView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var errorMessage: String?
    /// Erst beim Erscheinen laden: Ein früher Zugriff auf `NSDocumentController.shared`
    /// legt den Controller an, bevor SwiftUI seinen eigenen einrichtet – das führt zum Absturz beim Start.
    @State private var recent: [RecentProject] = []
    @State private var lastProject: URL?

    var body: some View {
        HStack(spacing: 0) {
            actions
            Divider()
            recentProjects
        }
        .frame(width: 800, height: 500)
        .background(Color.brandDark)
        .preferredColorScheme(.dark)
        .task {
            recent = NSDocumentController.shared.recentDocumentURLs.map(RecentProject.init)
            lastProject = SessionStore.lastProjectURL
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
            if let lastProject {
                Button { open(lastProject) } label: {
                    Label("„\(lastProject.deletingPathExtension().lastPathComponent)“ fortsetzen", systemImage: "play.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Theme.Spacing.xs)
                        .lineLimit(1)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color.brandOrange)
                .keyboardShortcut(.defaultAction)
            }
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
                List(recent) { project in
                    RecentProjectRow(project: project) { open(project.url) }
                }
                .scrollContentBackground(.hidden)
            }
            Spacer(minLength: 0)
            WelcomeInfo().padding(.horizontal, Theme.Spacing.l)
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

    /// Sobald ein Projekt offen ist (auch nach Absturz automatisch wiederhergestellt), verschwindet das Fenster.
    private func closeWhenProjectOpens() async {
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

/// Eintrag der Liste „Zuletzt geöffnet“ mit Ordner, Änderungsdatum und Hinweis, falls die Datei fehlt.
struct RecentProject: Identifiable {
    let url: URL
    let modified: Date?
    let exists: Bool

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }

    init(url: URL) {
        self.url = url
        exists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}

private struct RecentProjectRow: View {
    let project: RecentProject
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(project.name).foregroundStyle(project.exists ? Color.brandPaper : Color.mutedLight)
                    Spacer()
                    detail.font(.caption).foregroundStyle(project.exists ? Color.mutedLight : Color.brandRed)
                }
                Text(project.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(Color.mutedLight)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .buttonStyle(.plain)
        .disabled(!project.exists)
    }

    @ViewBuilder private var detail: some View {
        if !project.exists {
            Text("nicht gefunden")
        } else if let modified = project.modified {
            Text(modified, format: .dateTime.day().month().year().hour().minute())
        }
    }
}

/// Nützliches für den Stand: angeschlossene Bildschirme und die wichtigsten Tasten.
private struct WelcomeInfo: View {
    @Environment(DisplayService.self) private var displays

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Divider().padding(.bottom, Theme.Spacing.xs)
            Label(displayText, systemImage: displays.displays.count > 1 ? "display.2" : "display")
            Label("Leertaste GO · B Black · P Pause · ⌘. Notfall-Stopp", systemImage: "keyboard")
        }
        .font(.caption)
        .foregroundStyle(Color.mutedLight)
    }

    private var displayText: String {
        let names = displays.displays.map { $0.isControlScreen ? String(localized: "\($0.name) (Steuerung)") : $0.name }
        let list = names.joined(separator: ", ")
        return displays.displays.count > 1 ? list : String(localized: "\(list) – kein externer Bildschirm angeschlossen")
    }
}
