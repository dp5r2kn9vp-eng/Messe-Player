import SwiftUI

/// Eingabe einer Zeit im Format `m:ss.cc` (tolerant: `42`, `1:05`, `0:42.3`), optional mit Stepper.
struct DurationField: View {
    @Binding var seconds: TimeInterval
    let range: ClosedRange<TimeInterval>
    /// Schrittweite des Steppers; `nil` blendet ihn aus (z. B. in Listenzeilen).
    var step: TimeInterval?
    var width: CGFloat = 64

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            TextField("Zeit", value: clampedSeconds, format: .cueTime)
                .labelsHidden()
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(width: width)
            if let step {
                Stepper("Zeit", value: $seconds, in: range, step: step)
                    .labelsHidden()
            }
        }
    }

    /// Eingetippte Werte werden auf den erlaubten Bereich begrenzt.
    private var clampedSeconds: Binding<TimeInterval> {
        Binding(get: { seconds }, set: { seconds = $0.clamped(to: range) })
    }
}
