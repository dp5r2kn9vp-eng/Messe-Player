import Foundation
import Observation

/// Einzige Quelle des Ausgabezustands und Loop-Engine.
/// Bilder wechseln nach ihrer Dauer, Videos melden ihr Ende (`mediaDidFinish`), danach folgt eine kurze schwarze Pause.
@Observable
final class OutputController {
    static let videoGap: Duration = .seconds(1)
    static let singleCrossfade: TimeInterval = 0.5

    private(set) var state = OutputState()
    /// Nächstes Medium im Loop, damit der Renderer es vorladen kann.
    private(set) var upcoming: PlayableMedium?
    private var playlist: LoopPlaylist?

    @ObservationIgnored private let scheduler: any StepScheduler
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var step = 0
    @ObservationIgnored private var pendingStep: Cancellation?

    init(scheduler: any StepScheduler = TaskStepScheduler()) {
        self.scheduler = scheduler
    }

    var playingGroupID: MediaGroup.ID? {
        playlist?.groupID
    }

    // MARK: Bedienung

    /// Black wirkt sofort und ohne Überblendung; ein laufender Loop läuft darunter weiter.
    func toggleBlack() {
        state.isBlack.toggle()
    }

    /// Zeigt ein Medium dauerhaft und beendet einen laufenden Loop. Black bleibt bestehen.
    func showSingle(_ item: PlayableMedium) {
        stopLoop()
        state.transition = Self.singleCrossfade
        state.content = .single(item)
    }

    func stop() {
        stopLoop()
        state.content = .idle
    }

    /// Startet einen Loop, optional ab einem bestimmten Eintrag.
    func startLoop(_ playlist: LoopPlaylist, at entryID: Entry.ID? = nil) {
        stopLoop()
        guard !playlist.items.isEmpty else {
            state.content = .idle
            return
        }
        self.playlist = playlist
        state.transition = playlist.crossfade
        let start = entryID.flatMap { id in playlist.items.firstIndex { $0.entryID == id } } ?? 0
        show(index: start)
    }

    /// Übernimmt Änderungen an der laufenden Gruppe, ohne den aktuellen Eintrag zu unterbrechen.
    func updateLoop(_ newPlaylist: LoopPlaylist) {
        guard let playlist, playlist.groupID == newPlaylist.groupID else { return }
        guard !newPlaylist.items.isEmpty else {
            stop()
            return
        }
        let currentEntry = playlist.items[index].entryID
        self.playlist = newPlaylist
        state.transition = newPlaylist.crossfade
        index = newPlaylist.items.firstIndex { $0.entryID == currentEntry } ?? min(index, newPlaylist.items.count - 1)
        upcoming = nextItem
        // Geänderte Texte des laufenden Eintrags sofort zeigen, ohne neu zu überblenden.
        if case .loop(var frame) = state.content, frame.entryID == newPlaylist.items[index].entryID {
            frame.layers = newPlaylist.items[index].layers
            state.content = .loop(frame)
        }
    }

    /// Meldung des Renderers: Video zu Ende oder Medium defekt.
    func mediaDidFinish(step finished: Int) {
        guard case .loop(let frame) = state.content, frame.step == finished, !frame.isGap else { return }
        guard frame.item.medium.kind == .video else {
            advance()
            return
        }
        var gap = frame
        gap.isGap = true
        state.content = .loop(gap)
        schedule(after: Self.videoGap)
    }

    // MARK: Abfragen für die Anzeige

    func isLive(_ medium: Medium) -> Bool {
        switch state.content {
        case .single(let item): item.medium.id == medium.id
        case .loop(let frame): !frame.isGap && frame.item.medium.id == medium.id
        case .idle: false
        }
    }

    func isLive(entry entryID: Entry.ID) -> Bool {
        guard case .loop(let frame) = state.content else { return false }
        return frame.entryID == entryID
    }

    // MARK: Ablauf

    private func show(index newIndex: Int) {
        guard let playlist else { return }
        index = newIndex % playlist.items.count
        step += 1
        let current = playlist.items[index]
        state.content = .loop(LoopFrame(
            groupID: playlist.groupID,
            entryID: current.entryID,
            item: current.item,
            layers: current.layers,
            step: step
        ))
        upcoming = nextItem
        if current.item.medium.kind == .image {
            schedule(after: .seconds(current.imageDuration))
        }
    }

    private func advance() {
        show(index: index + 1)
    }

    private func schedule(after delay: Duration) {
        pendingStep?.cancel()
        pendingStep = scheduler.schedule(after: delay) { [weak self] in self?.advance() }
    }

    private func stopLoop() {
        pendingStep?.cancel()
        pendingStep = nil
        playlist = nil
        upcoming = nil
    }

    private var nextItem: PlayableMedium? {
        playlist.map { $0.items[(index + 1) % $0.items.count].item }
    }
}
