import SwiftUI

/// Balken eines Cues (░ Warten, ━ Dauer, danach stehend) oder ⟲-Abschnitt einer Gruppe; Klick wählt in der Liste.
struct TimelineItemView: View {
    let item: TimelineItem
    let scale: TrimScale
    let color: Color
    @Binding var selection: Set<UUID>
    @Environment(\.cueNames) private var cueNames

    var body: some View {
        content
            .frame(height: 18)
            .contentShape(Rectangle())
            .onTapGesture { selection = [selectionID] }
            .help(helpText)
    }

    @ViewBuilder private var content: some View {
        switch item {
        case .bar(let bar): barView(bar)
        case .loop(let loop): loopView(loop)
        }
    }

    // MARK: Cue

    private func barView(_ bar: TimelineBar) -> some View {
        let appear = bar.appear ?? bar.end ?? scale.length
        let end = bar.end ?? scale.length
        let visible = bar.appear == nil ? end : bar.visibleUntil ?? scale.length
        let isOpen = bar.appear != nil && (bar.end == nil || bar.visibleUntil == nil)
        return HStack(spacing: 0) {
            segment(from: bar.start, to: appear) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.15))
                    .strokeBorder(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            segment(from: appear, to: end) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.85))
                    .overlay(alignment: .leading) { title(cueNames(bar.cueID)) }
            }
            segment(from: end, to: visible) {
                Rectangle().fill(color.opacity(0.3))
            }
        }
        .overlay(alignment: .trailing) {
            if isOpen || bar.holds { openMarker }
        }
        .overlay {
            if selection.contains(bar.cueID) {
                RoundedRectangle(cornerRadius: 2).strokeBorder(Color.white, lineWidth: 2)
            }
        }
    }

    // MARK: Gruppe

    private func loopView(_ loop: TimelineLoop) -> some View {
        segment(from: loop.start, to: loop.end ?? scale.length) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.2))
                .strokeBorder(selection.contains(loop.groupID) ? Color.white : color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .overlay(alignment: .leading) {
                    Label(loopTitle(loop), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .lineLimit(1)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
                .overlay(alignment: .trailing) {
                    if loop.end == nil || loop.holds { openMarker }
                }
        }
    }

    private func loopTitle(_ loop: TimelineLoop) -> String {
        let title = switch loop.mode {
        case .loop: String(localized: "Loop")
        case .repeatCount(let count): String(localized: "\(count) Durchläufe")
        }
        return loop.isShuffled ? String(localized: "\(title) · Zufall") : title
    }

    // MARK: Bausteine

    private func segment(from start: TimeInterval, to end: TimeInterval, @ViewBuilder _ shape: () -> some View) -> some View {
        shape().frame(width: max(scale.x(end) - scale.x(start), 0))
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .foregroundStyle(Color.brandDark)
            .padding(.horizontal, Theme.Spacing.xs)
    }

    private var openMarker: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 9, weight: .bold))
            .padding(.trailing, 2)
    }

    private var selectionID: UUID {
        switch item {
        case .bar(let bar): bar.cueID
        case .loop(let loop): loop.groupID
        }
    }

    private var helpText: String {
        switch item {
        case .bar(let bar):
            let end = bar.end.map(TimeFormat.string(from:)) ?? "…"
            return "\(cueNames(bar.cueID)): \(TimeFormat.string(from: bar.start)) – \(end)"
        case .loop(let loop):
            return "\(loopTitle(loop)) ab \(TimeFormat.string(from: loop.start))"
        }
    }
}
