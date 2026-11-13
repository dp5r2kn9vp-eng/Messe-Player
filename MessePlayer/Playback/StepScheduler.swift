/// Zeitgeber der Cue-Engine (ein Handle je Cue). Austauschbar, damit Tests ohne echtes Warten laufen.
protocol StepScheduler {
    func schedule(after delay: Duration, _ action: @escaping () -> Void) -> Cancellation
}

struct Cancellation {
    let cancel: () -> Void
}

struct TaskStepScheduler: StepScheduler {
    func schedule(after delay: Duration, _ action: @escaping () -> Void) -> Cancellation {
        let task = Task {
            try? await Task.sleep(for: delay)
            if !Task.isCancelled { action() }
        }
        return Cancellation(cancel: task.cancel)
    }
}
