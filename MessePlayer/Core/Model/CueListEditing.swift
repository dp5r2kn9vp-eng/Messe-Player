import Foundation

/// Eine Änderung aus der Cue-Liste. Bei Mehrfachauswahl gilt sie für alle markierten Cues (außer Nummer und Name).
nonisolated enum CueEdit: Equatable {
    case number(String)
    case name(String)
    case output(OutputDefinition.ID?)
    case wait(TimeInterval)
    case duration(TimeInterval)
    case followAction(FollowAction)
    case postWait(TimeInterval)
    case notes(String)
    case color(RGBAColor?)
    /// Medium ersetzen; In- und Out-Punkt beginnen neu.
    case medium(Medium.ID)
    case scaling(ContentScaling)
    case blendIn(TimeInterval)
    case blendOut(TimeInterval)
    case volume(Double)
    case fadeIn(TimeInterval)
    case fadeOut(TimeInterval)
    case muted(Bool)
    /// Trim (nur Video/Audio): In-/Out-Punkt in Sekunden der Quelle; `resetTrim` = volle Länge.
    case inPoint(TimeInterval)
    case outPoint(TimeInterval)
    case resetTrim

    /// Nummer, Name, Medium und In/Out sind je Cue eigen und gelten nie für eine Mehrfachauswahl.
    var appliesToSelection: Bool {
        switch self {
        case .number, .name, .medium, .inPoint, .outPoint: false
        default: true
        }
    }
}

nonisolated extension Cue {
    static let waitRange: ClosedRange<TimeInterval> = 0...3600

    /// Ändert eine Ebene, falls vorhanden.
    mutating func updateLayer(_ id: Layer.ID, _ change: (inout Layer) -> Void) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        change(&layers[index])
    }
}

/// Bearbeitung der Cue-Liste: Werte setzen, Cues einfügen und verschieben, Gruppen bilden und auflösen.
nonisolated extension Project {
    /// Wendet eine Änderung auf die Cues `ids` an. `mediaLength` liefert die Länge von Video/Audio, falls bekannt.
    mutating func apply(_ edit: CueEdit, to ids: Set<Cue.ID>, mediaLength: (Cue) -> TimeInterval? = { _ in nil }) {
        for index in cues.indices where ids.contains(cues[index].id) {
            let cue = cues[index]
            switch edit {
            case .number(let number):
                cues[index].number = number.trimmingCharacters(in: .whitespaces)
            case .name(let name):
                cues[index].name = name
            case .output(let outputID):
                if !isAudio(cue) { cues[index].outputID = outputID }
            case .wait(let seconds):
                cues[index].wait = seconds.clamped(to: Cue.waitRange)
            case .duration(let seconds):
                setDuration(seconds, at: index, mediaLength: mediaLength(cue))
            case .inPoint, .outPoint, .resetTrim:
                applyTrim(edit, at: index, mediaLength: mediaLength(cue))
            case .followAction(let action):
                cues[index].followAction = action
            case .postWait(let seconds):
                cues[index].postWait = seconds.clamped(to: Cue.waitRange)
            case .notes(let notes):
                cues[index].notes = notes
            case .color(let color):
                cues[index].color = color
            case .medium(let mediumID):
                replaceMedium(at: index, with: mediumID)
            default:
                applyPlayback(edit, at: index)
            }
        }
    }

    /// Bild-, Blend- und Audio-Werte; Audio-Werte nur bei Video und Audio, Bild-Werte nicht bei Audio.
    private mutating func applyPlayback(_ edit: CueEdit, at index: Int) {
        let kind = cues[index].mediumID.flatMap(medium(withID:))?.kind
        let hasSound = kind == .video || kind == .audio
        switch edit {
        case .scaling(let scaling) where kind != .audio: cues[index].scaling = scaling
        case .blendIn(let seconds) where kind != .audio: cues[index].blendIn = seconds
        case .blendOut(let seconds) where kind != .audio: cues[index].blendOut = seconds
        case .volume(let volume) where hasSound: cues[index].volume = volume
        case .fadeIn(let seconds) where hasSound: cues[index].fadeIn = seconds
        case .fadeOut(let seconds) where hasSound: cues[index].fadeOut = seconds
        case .muted(let isMuted) where hasSound: cues[index].isMuted = isMuted
        default: break
        }
    }

    /// Audio belegt keinen Ausgang; wird aus Audio ein Bild/Video, bekommt es den ersten Ausgang.
    private mutating func replaceMedium(at index: Int, with mediumID: Medium.ID) {
        guard let medium = medium(withID: mediumID) else { return }
        cues[index].mediumID = mediumID
        cues[index].inPoint = 0
        cues[index].outPoint = nil
        cues[index].outputID = medium.kind == .audio ? nil : cues[index].outputID ?? outputs.first?.id
    }

    /// Bild: Standdauer. Video/Audio: Kürzen setzt den Out-Punkt (höchstens bis Medienende).
    private mutating func setDuration(_ seconds: TimeInterval, at index: Int, mediaLength: TimeInterval?) {
        guard let medium = cues[index].mediumID.flatMap(medium(withID:)) else { return }
        guard medium.kind != .image else {
            cues[index].stillDuration = seconds
            return
        }
        var trim = cues[index].trim(mediaLength: mediaLength)
        trim.setDuration(seconds)
        cues[index].applyTrim(trim)
    }

    /// In/Out und Zurücksetzen, nur bei Video und Audio.
    private mutating func applyTrim(_ edit: CueEdit, at index: Int, mediaLength: TimeInterval?) {
        guard let kind = cues[index].mediumID.flatMap(medium(withID:))?.kind, kind != .image else { return }
        var trim = cues[index].trim(mediaLength: mediaLength)
        switch edit {
        case .inPoint(let seconds): trim.setIn(seconds)
        case .outPoint(let seconds): trim.setOut(seconds)
        case .resetTrim: trim.reset()
        default: return
        }
        cues[index].applyTrim(trim)
    }

    func isAudio(_ cue: Cue) -> Bool {
        cue.mediumID.flatMap(medium(withID:))?.kind == .audio
    }

    /// Legt je Medium einen Cue an Position `offset` an (Bild 5 s, Video/Audio = Medienlänge) und liefert ihre IDs.
    @discardableResult
    mutating func insertCues(for mediumIDs: [Medium.ID], at offset: Int, joining groupID: CueGroup.ID? = nil) -> [Cue.ID] {
        var number = highestCueNumber
        let newCues = mediumIDs.compactMap(medium(withID:)).map { medium in
            number += 1
            var cue = Cue(number: String(number), mediumID: medium.id, outputID: medium.kind == .audio ? nil : outputs.first?.id)
            cue.name = (medium.displayName as NSString).deletingPathExtension
            return cue
        }
        var membership = groupMembership
        if let groupID { newCues.forEach { membership[$0.id] = groupID } }
        cues.insert(contentsOf: newCues, at: min(max(offset, 0), cues.count))
        rebuildGroups(from: membership)
        return newCues.map(\.id)
    }

    /// Verschiebt Cues vor die Position `offset` (Zählung wie `Array.move(fromOffsets:toOffset:)`).
    /// Mit `groupID` treten sie der Gruppe bei; sonst verlassen sie ihre Gruppe, außer die ganze Gruppe zieht mit.
    mutating func moveCues(_ ids: Set<Cue.ID>, toOffset offset: Int, joining groupID: CueGroup.ID?) {
        let membership = groupMembership
        let wholeGroups = Set(groups.filter { group in
            let members = membership.filter { $0.value == group.id }.keys
            return !members.isEmpty && members.allSatisfy(ids.contains)
        }.map(\.id))
        var newMembership = membership
        for id in ids {
            if let groupID {
                newMembership[id] = groupID
            } else if let current = membership[id], !wholeGroups.contains(current) {
                newMembership[id] = nil
            }
        }
        let offsets = IndexSet(cues.indices.filter { ids.contains(cues[$0].id) })
        cues.move(fromOffsets: offsets, toOffset: min(max(offset, 0), cues.count))
        rebuildGroups(from: newMembership)
    }

    /// `true`, wenn die Cues zusammenhängen und keine bestehende Gruppe nur teilweise erfassen.
    func canFormGroup(from ids: Set<Cue.ID>) -> Bool {
        groupBounds(for: ids) != nil
    }

    /// Bildet eine Loop-Gruppe aus zusammenhängenden Cues. Ganz enthaltene Gruppen gehen darin auf (keine Verschachtelung).
    @discardableResult
    mutating func formGroup(from ids: Set<Cue.ID>) -> CueGroup.ID? {
        guard let bounds = groupBounds(for: ids) else { return nil }
        let absorbed = Set(groups.filter { cueRange(of: $0).map { bounds.contains($0.lowerBound) } == true }.map(\.id))
        groups.removeAll { absorbed.contains($0.id) }
        let group = CueGroup(name: nextGroupName, firstCueID: cues[bounds.lowerBound].id, lastCueID: cues[bounds.upperBound].id)
        groups.append(group)
        sortGroupsByPosition()
        return group.id
    }

    /// Löst die Gruppen auf, die einen der Cues enthalten oder deren ID in `ids` steht. Die Cues bleiben.
    mutating func dissolveGroups(touching ids: Set<UUID>) {
        let indices = Set(cues.indices.filter { ids.contains(cues[$0].id) })
        let touched = Set(groups.filter { group in
            ids.contains(group.id) || cueRange(of: group).map { !indices.isDisjoint(with: Set($0)) } == true
        }.map(\.id))
        groups.removeAll { touched.contains($0.id) }
    }

    /// Setzt den Ausgang aller Bild-/Video-Cues einer Gruppe (eine Gruppe hat genau einen Ausgang).
    mutating func setOutput(_ outputID: OutputDefinition.ID?, forGroup groupID: CueGroup.ID) {
        guard let group = groups.first(where: { $0.id == groupID }), let range = cueRange(of: group) else { return }
        apply(.output(outputID), to: Set(cues[range].map(\.id)))
    }

    func members(of group: CueGroup) -> [Cue] {
        cueRange(of: group).map { Array(cues[$0]) } ?? []
    }

    /// Summe der Dauern einer Gruppe; `nil`, solange eine Länge unbekannt ist.
    func duration(of group: CueGroup, mediaLength: (Cue) -> TimeInterval?) -> TimeInterval? {
        members(of: group).reduce(TimeInterval?(0)) { sum, cue in
            guard let sum, let duration = duration(of: cue, mediaLength: mediaLength(cue)) else { return nil }
            return sum + cue.wait + duration
        }
    }

    /// In Gruppen gilt „Weiter nach Ende“; nur der letzte Cue bestimmt, was nach der Gruppe passiert
    /// (nach n Durchläufen bzw. nach „Loop beenden“).
    func followActionIsSetByGroup(_ cue: Cue) -> Bool {
        guard let group = group(containing: cue.id) else { return false }
        return group.lastCueID != cue.id
    }

    /// Nachwarten wirkt nur bei „Mit nächstem starten“ außerhalb von Gruppen.
    func postWaitApplies(to cue: Cue) -> Bool {
        cue.followAction == .continueWithNext && group(containing: cue.id) == nil
    }

    /// Zuordnung Cue → Gruppe für alle Cues in Gruppen.
    var groupMembership: [Cue.ID: CueGroup.ID] {
        var membership: [Cue.ID: CueGroup.ID] = [:]
        for group in groups {
            for cue in members(of: group) { membership[cue.id] = group.id }
        }
        return membership
    }

    // MARK: Hilfen

    private var nextGroupName: String {
        String(localized: "Gruppe \(groups.count + 1)")
    }

    private func groupBounds(for ids: Set<Cue.ID>) -> ClosedRange<Int>? {
        let indices = cues.indices.filter { ids.contains(cues[$0].id) }
        guard let first = indices.first, let last = indices.last, last - first + 1 == indices.count else { return nil }
        let bounds = first...last
        let cutsGroup = groups.compactMap(cueRange).contains { range in
            range.overlaps(bounds) && !(bounds.contains(range.lowerBound) && bounds.contains(range.upperBound))
        }
        return cutsGroup ? nil : bounds
    }

    /// Setzt die Grenzen aller Gruppen nach `membership`; Gruppen ohne Cues entfallen.
    private mutating func rebuildGroups(from membership: [Cue.ID: CueGroup.ID]) {
        groups = groups.compactMap { group in
            let members = cues.filter { membership[$0.id] == group.id }
            guard let first = members.first, let last = members.last else { return nil }
            var updated = group
            updated.firstCueID = first.id
            updated.lastCueID = last.id
            return updated
        }
        sortGroupsByPosition()
    }

    private mutating func sortGroupsByPosition() {
        let positions = Dictionary(groups.map { ($0.id, cueRange(of: $0)?.lowerBound ?? .max) }, uniquingKeysWith: { first, _ in first })
        groups.sort { (positions[$0.id] ?? .max) < (positions[$1.id] ?? .max) }
    }
}
