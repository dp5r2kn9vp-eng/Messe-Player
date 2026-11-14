import SwiftUI

/// Oranger Balken mit Restzeit: wie lange der aktuelle Eintrag noch auf dem Ausgang steht.
struct StepProgressBar: View {
    let progress: StepProgress

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { context in
            let elapsed = (progress.pausedAt ?? context.date).timeIntervalSince(progress.startedAt)
            let remaining = max(progress.duration - elapsed, 0)
            HStack(spacing: Theme.Spacing.s) {
                bar(fraction: progress.duration > 0 ? min(elapsed / progress.duration, 1) : 1)
                Text(progress.pausedAt == nil ? TimeFormat.countdown(from: remaining) : String(localized: "Pause"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.brandOrange)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .help("Restzeit bis zum nächsten Eintrag")
    }

    /// Eigener Balken statt `ProgressView`, damit er auch in inaktiven Fenstern orange bleibt.
    private func bar(fraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.mutedDark.opacity(0.5))
                Capsule().fill(Color.brandOrange).frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}
