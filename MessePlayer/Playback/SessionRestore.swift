import Foundation

extension CueEngine {
    /// Aktueller Zustand als speicherbarer Schnappschuss.
    func snapshot(projectPath: String?) -> SessionSnapshot {
        SessionSnapshot(projectPath: projectPath, visibleCueIDs: visibleCueIDs, playheadID: playheadID, isBlack: isBlack, blackOutputIDs: blackOutputIDs.sorted { $0.uuidString < $1.uuidString })
    }

    /// Startet die zuletzt sichtbaren Cues neu und stellt Abspielkopf und Black (alle und je Ausgang) wieder her.
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
        for id in Set(snapshot.blackOutputIDs).symmetricDifference(blackOutputIDs) where show.outputs.contains(where: { $0.id == id }) {
            toggleBlack(output: id)
        }
    }
}
