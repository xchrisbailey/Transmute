import Foundation

extension SessionSnapshot {
    /// This snapshot with a command applied, the way the owner will apply it to the workout.
    ///
    /// The mirroring device shows the result while the command is on its way; the owner's next
    /// snapshot then replaces it. A command that no longer fits (the set is gone, the session
    /// has ended) changes nothing. `discard` changes nothing either: there's no snapshot of a
    /// workout that isn't there, so the mirror waits to be told the session ended.
    public func applying(_ command: SessionCommand) -> SessionSnapshot {
        guard !isFinished else { return self }
        var next = self
        switch command {
        case .logSet(let ref, let values, let date):
            next.log(ref, values, at: date)
        case .reopenSet(let ref):
            next.withSet(at: ref) { set in
                set.isCompleted = false
                set.completedAt = nil
            }
        case .updateSet(let ref, let values):
            next.withSet(at: ref) { $0.write(values) }
        case .startRest(let seconds, let date):
            next.startRest(seconds, at: date)
        case .adjustRest(let seconds, let date):
            next.adjustRest(by: seconds, at: date)
        case .setSkipped(let order, let isSkipped):
            next.setSkipped(order, isSkipped)
        case .finish(let date):
            next.finish(at: date)
        case .discard:
            break
        }
        return next
    }

    private mutating func withSet(at ref: SetRef, _ change: (inout Set) -> Void) {
        guard let exercise = exercises.firstIndex(where: { $0.order == ref.exerciseOrder }),
            let set = exercises[exercise].sets.firstIndex(where: { $0.order == ref.setOrder })
        else { return }
        change(&exercises[exercise].sets[set])
    }

    /// Checks a set off and starts its rest, unless it was the last set of the workout or
    /// rest doesn't start by itself.
    private mutating func log(_ ref: SetRef, _ values: SetValues, at date: Date) {
        guard let set = set(at: ref), !set.isCompleted else { return }
        withSet(at: ref) { set in
            set.write(values)
            set.isCompleted = true
            set.completedAt = date
        }
        let rest: Double? =
            if autoStartsRest != false, current != nil, let seconds = set.restSeconds, seconds > 0 {
                seconds
            } else {
                nil
            }
        startRest(rest, at: date)
    }

    private mutating func startRest(_ seconds: Double?, at date: Date) {
        restSeconds = seconds
        restEndsAt = seconds.map { date.addingTimeInterval($0) }
    }

    private mutating func adjustRest(by seconds: Double, at date: Date) {
        guard let remaining = restRemaining(at: date) else { return }
        let new = max(0, remaining + seconds)
        restEndsAt = new == 0 ? nil : date.addingTimeInterval(new)
        restSeconds = max(new, (restSeconds ?? 0) + seconds)
    }

    private mutating func setSkipped(_ order: Int, _ isSkipped: Bool) {
        guard let index = exercises.firstIndex(where: { $0.order == order }) else { return }
        exercises[index].isSkipped = isSkipped
    }

    /// Unlogged sets go, as do exercises left with nothing logged, and the rest timer stops.
    private mutating func finish(at date: Date) {
        for index in exercises.indices {
            exercises[index].sets.removeAll { !$0.isCompleted }
        }
        exercises.removeAll { $0.sets.isEmpty }
        endedAt = date
        restEndsAt = nil
        restSeconds = nil
    }
}

extension SessionSnapshot.Set {
    fileprivate mutating func write(_ values: SetValues) {
        weightKg = values.weightKg
        reps = values.reps
        seconds = values.seconds
        meters = values.meters
        rpe = values.rpe
    }
}
