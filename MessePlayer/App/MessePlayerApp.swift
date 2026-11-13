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
        }
    }
}
