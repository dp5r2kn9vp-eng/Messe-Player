import Foundation

extension CueEngine {
    /// Aktueller Zustand als speicherbarer Schnappschuss.
    func snapshot(projectPath: String?) -> SessionSnapshot {
        SessionSnapshot(projectPath: projectPath, visibleCueIDs: visibleCueIDs, playheadID: playheadID, isBlack: isBlack)
    }

    /// Startet die zuletzt sichtbaren Cues neu und stellt Abspielkopf und Black wieder her.
    /// Fehlen Cues inzwischen, bleibt der Ausgang im Ruhezustand.
    func restore(_ snapshot: SessionSnapshot) {
        for id in snapshot.visibleCueIDs {
            start(id)
        }
        if let playheadID = snapshot.playheadID, show.index(of: playheadID) != nil {
            setPlayhead(playheadID)
        }
        if snapshot.isBlack != isBlack {
            toggleBlack()
        }
    }
}
