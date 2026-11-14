import Foundation

/// Reihenfolge der Cues in einem Durchlauf einer Gruppe (Listenfolge oder zufällig).
enum GroupOrder {
    /// Mischt eine Liste; im Programm zufällig, in Tests und im Zeitstrahl festgelegt.
    typealias Shuffle = ([Cue.ID]) -> [Cue.ID]

    static let random: Shuffle = { $0.shuffled() }

    /// Cues eines Durchlaufs.
    /// - `first`: Startet der Durchlauf bei einem bestimmten Cue (Doppelklick), steht er vorn;
    ///   in Listenfolge entfallen die Cues davor.
    /// - `previousLast`: Letzter Cue des vorigen Durchlaufs; im Zufallsmodus steht er nicht direkt wieder vorn.
    static func pass(
        of ids: [Cue.ID],
        isShuffled: Bool,
        first: Cue.ID? = nil,
        previousLast: Cue.ID? = nil,
        shuffle: Shuffle
    ) -> [Cue.ID] {
        guard isShuffled else {
            return first.map { start in Array(ids.drop { $0 != start }) } ?? ids
        }
        if let first, ids.contains(first) {
            return [first] + shuffle(ids.filter { $0 != first })
        }
        var order = shuffle(ids)
        if order.count > 1, order.first == previousLast {
            order.swapAt(0, order.count - 1)
        }
        return order
    }
}
