import SwiftUI

@main
struct MessePlayerApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        DocumentGroup(newDocument: ProjectDocument()) { file in
            ControlView(document: file.$document, packageURL: file.fileURL)
                .environment(appDelegate.output)
                .environment(appDelegate.displays)
                .environment(appDelegate.outputWindow)
                .environment(appDelegate.hotkeys)
                .focusedSceneValue(\.projectPackageURL, file.fileURL)
        }
        .commands {
            ArchiveCommands()
            PlaybackCommands(output: appDelegate.output)
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
