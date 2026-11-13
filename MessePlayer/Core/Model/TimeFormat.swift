import Foundation

/// Zeitangaben der Cue-Liste im Format `m:ss.cc` (z. B. `0:42.30`). Intern Sekunden als `Double`.
nonisolated enum TimeFormat {
    /// Formatiert auf Hundertstel gerundet, Minuten ohne Obergrenze.
    static func string(from seconds: TimeInterval) -> String {
        let hundredths = Int((max(seconds, 0) * 100).rounded())
        let minutes = hundredths / 6000
        let rest = hundredths % 6000
        return String(format: "%d:%02d.%02d", minutes, rest / 100, rest % 100)
    }

    /// Tolerante Eingabe: `42`, `42.5`, `42,5`, `1:05`, `0:42.3`, `1:02:03` (h:m:s).
    /// `nil` bei unlesbarer oder negativer Eingabe sowie bei Sekunden/Minuten ≥ 60 hinter einem Doppelpunkt.
    static func seconds(from text: String) -> TimeInterval? {
        let parts = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count),
              let last = Double(parts[parts.count - 1]), last.isFinite, last >= 0
        else { return nil }
        guard parts.count > 1 else { return last }
        guard last < 60 else { return nil }

        var total = last
        var factor: TimeInterval = 60
        for (offset, part) in parts.dropLast().reversed().enumerated() {
            guard let value = Int(part), value >= 0 else { return nil }
            let isInnerMinutes = offset == 0 && parts.count == 3
            if isInnerMinutes && value >= 60 { return nil }
            total += Double(value) * factor
            factor *= 60
        }
        return total
    }
}
