import Foundation

extension OutputController {
    /// Aktueller Zustand als speicherbarer Schnappschuss.
    func snapshot(projectPath: String?) -> SessionSnapshot {
        let mode: SessionSnapshot.Mode = switch state.content {
        case .idle: .idle
        case .single(let item): .single(item.medium.id)
        case .loop(let frame): .loop(frame.groupID, frame.entryID)
        }
        return SessionSnapshot(projectPath: projectPath, mode: mode, isBlack: state.isBlack)
    }

    /// Stellt einen gespeicherten Zustand für das passende Projekt wieder her.
    /// Fehlen Gruppe oder Medium inzwischen, bleibt der Ausgang im Ruhezustand.
    func restore(_ snapshot: SessionSnapshot, from document: ProjectDocument, packageURL: URL?) {
        switch snapshot.mode {
        case .idle:
            break
        case .single(let mediumID):
            if let medium = document.project.medium(withID: mediumID), let item = document.playable(medium, in: packageURL) {
                showSingle(item)
            }
        case .loop(let groupID, let entryID):
            if let group = document.project.groups.first(where: { $0.id == groupID }) {
                startLoop(document.playlist(for: group, in: packageURL), at: entryID)
            }
        }
        if snapshot.isBlack != state.isBlack {
            toggleBlack()
        }
    }
}
