import SwiftUI

@main
struct MessePlayerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        DocumentGroup(newDocument: ProjectDocument()) { file in
            ControlView(document: file.$document, packageURL: file.fileURL)
                .environment(appDelegate.engine)
                .environment(appDelegate.displays)
                .environment(appDelegate.outputWindows)
                .environment(appDelegate.routing)
                .environment(appDelegate.hotkeys)
                .environment(appDelegate.mediaLengths)
                .focusedSceneValue(\.projectPackageURL, file.fileURL)
        }
        .commands {
            ArchiveCommands()
            PlaybackCommands(engine: appDelegate.engine)
            InfoCommands()
        }
        Window("Willkommen bei CueView", id: WindowID.welcome) {
            WelcomeView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)
        Window("Über CueView", id: WindowID.about) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        Window("CueView-Hilfe", id: WindowID.help) {
            HelpView()
        }
        .defaultLaunchBehavior(.suppressed)
        Window("Tastenkürzel", id: WindowID.shortcuts) {
            ShortcutsView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
