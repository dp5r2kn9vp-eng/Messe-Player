import Foundation

/// Eine sichtbare Zeile der Cue-Liste: Gruppenkopf oder Cue (in einer Gruppe mit Klammer).
nonisolated enum CueListRow: Identifiable, Equatable {
    case group(CueGroup)
    case cue(Cue, bracket: GroupBracket?)

    /// Gruppen- und Cue-IDs sind beide UUIDs und damit gemeinsam als Auswahl nutzbar.
    var id: UUID {
        switch self {
        case .group(let group): group.id
        case .cue(let cue, _): cue.id
        }
    }
}

/// Teil der Gruppenklammer links neben einem Cue (Kopfzeile = ┌, Mitglied = │, letztes = └).
nonisolated enum GroupBracket: Equatable {
    case member(groupID: CueGroup.ID)
    case last(groupID: CueGroup.ID)

    var groupID: CueGroup.ID {
        switch self {
        case .member(let id), .last(let id): id
        }
    }
}

/// Wohin eine Ablage in der Liste führt: Position in `Project.cues` und ggf. die Gruppe, der die Cues beitreten.
nonisolated struct CueDropTarget: Equatable {
    let offset: Int
    let groupID: CueGroup.ID?
}

nonisolated extension Project {
    /// Zeilen der Liste: vor den Mitgliedern einer Gruppe ihr Kopf; zugeklappte Gruppen zeigen nur den Kopf.
    var listRows: [CueListRow] {
        let ranges = groups.compactMap { group in cueRange(of: group).map { (group, $0) } }
        var rows: [CueListRow] = []
        for (index, cue) in cues.enumerated() {
            guard let (group, range) = ranges.first(where: { $0.1.contains(index) }) else {
                rows.append(.cue(cue, bracket: nil))
                continue
            }
            if index == range.lowerBound { rows.append(.group(group)) }
            guard !group.isCollapsed else { continue }
            rows.append(.cue(cue, bracket: index == range.upperBound ? .last(groupID: group.id) : .member(groupID: group.id)))
        }
        return rows
    }

    /// Cue-IDs einer Auswahl aus Zeilen; ein Gruppenkopf steht für alle Mitglieder.
    func cueIDs(inSelection selection: Set<UUID>) -> Set<Cue.ID> {
        var ids = Set(cues.map(\.id)).intersection(selection)
        for group in groups where selection.contains(group.id) {
            ids.formUnion(members(of: group).map(\.id))
        }
        return ids
    }

    /// Ziel einer Ablage vor Zeile `rowIndex` von `rows`.
    /// Zwischen Kopf/Mitgliedern einer Gruppe tritt man ihr bei; direkt hinter dem letzten Mitglied nur, wenn alle bewegten Cues schon dazugehören.
    func dropTarget(in rows: [CueListRow], before rowIndex: Int, moving moved: Set<Cue.ID> = []) -> CueDropTarget {
        let next = rows.indices.contains(rowIndex) ? rows[rowIndex] : nil
        let previous = rows.indices.contains(rowIndex - 1) ? rows[rowIndex - 1] : nil
        let offset: Int = switch next {
        case .cue(let cue, _): cues.firstIndex { $0.id == cue.id } ?? cues.count
        case .group(let group): cueRange(of: group)?.lowerBound ?? cues.count
        case nil: cues.count
        }
        let membership = groupMembership
        let groupID: CueGroup.ID? = switch previous {
        case .group(let group) where !group.isCollapsed:
            group.id
        case .cue(_, .member(let groupID)):
            groupID
        case .cue(_, .last(let groupID)) where !moved.isEmpty && moved.allSatisfy({ membership[$0] == groupID }):
            groupID
        default:
            nil
        }
        return CueDropTarget(offset: offset, groupID: groupID)
    }
}
