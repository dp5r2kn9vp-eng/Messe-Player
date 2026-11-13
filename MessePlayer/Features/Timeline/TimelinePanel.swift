import SwiftUI

/// Show-Zeitstrahl (Gantt) unter der Cue-Liste: simuliert die Liste und zeigt je Ausgang und Tonspur, wann welcher Cue läuft.
/// Nur Ansicht; ein Klick wählt den Cue (bzw. die Gruppe) in der Liste.
struct TimelinePanel: View {
    let show: CueShow
    @Binding var selection: Set<UUID>
    @State private var layout: TimelineLayout?

    /// Darüber scrollen die Spuren senkrecht.
    static let maxChartHeight: CGFloat = 220

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let layout {
                ScrollView(.vertical) {
                    TimelineChart(layout: layout, selection: $selection)
                }
                .frame(height: min(TimelineChart.contentHeight(of: layout), Self.maxChartHeight))
            }
        }
        .onChange(of: show, initial: true) {
            layout = TimelineLayout(timeline: ShowSimulation.run(show), outputs: show.outputs)
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Zeitstrahl").font(.headline)
            Text("Simulation ab dem ersten Cue, jedes GO sofort")
                .font(.caption)
                .foregroundStyle(Color.mutedLight)
            Spacer()
            Text("░ Warten   ━ Dauer   ⟲ Loop   → Halten / offen")
                .font(.caption.monospaced())
                .foregroundStyle(Color.mutedLight)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }
}

/// Spurnamen links, Zeitleiste und Spuren rechts (waagerecht scrollbar).
private struct TimelineChart: View {
    let layout: TimelineLayout
    @Binding var selection: Set<UUID>

    static let labelWidth: CGFloat = 96
    static let rowHeight: CGFloat = 22
    static let rulerHeight: CGFloat = 18
    /// Mindestauflösung; kurze Shows füllen die Breite.
    static let pointsPerSecond: CGFloat = 12

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            laneLabels
            GeometryReader { proxy in
                let width = max(proxy.size.width - Theme.Spacing.m, CGFloat(layout.length) * Self.pointsPerSecond)
                let scale = TrimScale(length: layout.length, width: width)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        TimelineRuler(scale: scale, goTimes: layout.goTimes)
                            .frame(height: Self.rulerHeight)
                        ForEach(layout.lanes) { lane in
                            laneRows(lane, scale: scale)
                        }
                    }
                    .frame(width: width, alignment: .leading)
                    .padding(.trailing, Theme.Spacing.m)
                }
            }
        }
        .frame(height: Self.contentHeight(of: layout))
    }

    /// Höhe aller Spuren; das Panel wächst mit, bis `TimelinePanel.maxChartHeight`, darüber scrollen die Spuren senkrecht.
    static func contentHeight(of layout: TimelineLayout) -> CGFloat {
        rulerHeight + layout.lanes.reduce(0) { $0 + laneHeight($1) }
    }

    private var laneLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(width: Self.labelWidth + Theme.Spacing.m, height: Self.rulerHeight)
            ForEach(layout.lanes) { lane in
                Label {
                    Text(lane.name).lineLimit(1)
                } icon: {
                    Circle().fill(color(of: lane)).frame(width: 8, height: 8)
                }
                .font(.caption)
                .frame(width: Self.labelWidth, height: Self.laneHeight(lane), alignment: .leading)
                .padding(.leading, Theme.Spacing.m)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }

    private func laneRows(_ lane: TimelineLayout.Lane, scale: TrimScale) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lane.rows.indices, id: \.self) { row in
                ZStack(alignment: .leading) {
                    ForEach(lane.rows[row]) { item in
                        TimelineItemView(item: item, scale: scale, color: color(of: lane), selection: $selection)
                            .offset(x: scale.x(item.start))
                    }
                }
                .frame(width: scale.width, height: Self.rowHeight, alignment: .leading)
            }
        }
        .frame(height: Self.laneHeight(lane), alignment: .top)
        .overlay(alignment: .bottom) { Divider() }
    }

    private static func laneHeight(_ lane: TimelineLayout.Lane) -> CGFloat {
        CGFloat(max(lane.rows.count, 1)) * rowHeight + Theme.Spacing.xs
    }

    private func color(of lane: TimelineLayout.Lane) -> Color {
        lane.outputIndex.map(Color.output(at:)) ?? .audioLane
    }
}

/// Zeitachse im Format `m:ss`; Markierungen an den Zeitpunkten, an denen ein GO nötig ist.
private struct TimelineRuler: View {
    let scale: TrimScale
    let goTimes: [TimeInterval]

    /// Mindestabstand der Beschriftungen in Punkten.
    static let labelSpacing: CGFloat = 70
    static let steps: [TimeInterval] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800]

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(ticks, id: \.self) { time in
                Text(TimeFormat.string(from: time).dropLast(3))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.mutedLight)
                    .offset(x: scale.x(time) + 2)
            }
            ForEach(goTimes, id: \.self) { time in
                Image(systemName: "play.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(Color.playhead)
                    .offset(x: scale.x(time), y: 6)
                    .help("GO bei \(TimeFormat.string(from: time))")
            }
        }
        .frame(width: scale.width, alignment: .leading)
    }

    private var ticks: [TimeInterval] {
        let perSecond = scale.length > 0 ? scale.width / CGFloat(scale.length) : 1
        let step = Self.steps.first { CGFloat($0) * perSecond >= Self.labelSpacing } ?? Self.steps[Self.steps.count - 1]
        return Array(stride(from: 0, through: scale.length, by: step))
    }
}
