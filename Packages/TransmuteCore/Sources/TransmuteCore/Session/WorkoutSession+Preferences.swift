import Foundation
import SwiftData

/// Where the workout preferences (#18) meet a session: default rests, warm-up sets and
/// starting rest by hand.
extension WorkoutSession {
    /// The sets a planned exercise starts with: the engine's targets, with rests filled in
    /// from the preferences and warm-ups added or left out as the person chose.
    ///
    /// Warm-ups a plan wrote are kept as they are. A barbell lift with none gets the usual ramp
    /// up to its first working weight. With warm-ups off, neither appears.
    static func sets(
        for planned: PlannedExercise, targets: [SetTarget], profile: Profile, library: ExerciseLibrary
    ) -> [LoggedSet] {
        let preferences = profile.preferences
        let keepsWarmUps = preferences.warmUpSets && planned.orderedSets.contains(where: \.isWarmUp)
        let plannedSets = planned.orderedSets.filter { keepsWarmUps || !$0.isWarmUp }
        let kept = targets.filter { keepsWarmUps || !$0.isWarmUp }
        var sets: [LoggedSet] = []
        if preferences.warmUpSets, !keepsWarmUps, let workingKg = kept.first?.loadKg {
            sets = rampSets(to: workingKg, exercise: library.exercise(id: planned.exerciseID), profile: profile)
        }
        for (index, target) in kept.enumerated() {
            let set = LoggedSet(target: target)
            let source = plannedSets.indices.contains(index) ? plannedSets[index] : plannedSets.last
            set.restSeconds =
                target.restSeconds ?? source?.restSeconds ?? preferences.restSeconds(isWarmUp: target.isWarmUp)
            set.intervalRestSeconds = target.intervalRestSeconds ?? source?.intervalRestSeconds
            sets.append(set)
        }
        for (index, set) in sets.enumerated() {
            set.order = index
        }
        return sets
    }

    /// The warm-up ramp to a working weight, as sets ready to log. Empty unless the lift is
    /// loaded on a bar the person has, since the ramp is worked out in plates.
    static func rampSets(to workingKg: Double, exercise: LibraryExercise?, profile: Profile) -> [LoggedSet] {
        guard let exercise, exercise.tracking == .weightReps else { return [] }
        let bars: Set<Equipment> = [.barbell, .trapBar]
        let equipment = exercise.allEquipment
        guard !equipment.isDisjoint(with: bars), !bars.isDisjoint(with: profile.equipment) else { return [] }
        let bar: BarKind? = equipment.contains(.trapBar) && !equipment.contains(.barbell) ? .trap : nil
        let rest = profile.preferences.warmUpRestSeconds
        return PlateCalculator(inventory: profile.plates, bar: bar).warmUps(to: workingKg).map { warmUp in
            let set = LoggedSet(order: 0, weightKg: warmUp.loading.totalKg, reps: warmUp.reps)
            set.isWarmUp = true
            set.restSeconds = rest
            return set
        }
    }

    /// The rest the last logged set asks for, when no rest is running and there's a set still
    /// to do. For starting rest by hand when it doesn't start by itself.
    public static func restToStart(in workout: Workout, at date: Date = .now) -> TimeInterval? {
        guard restRemaining(in: workout, at: date) == nil, currentSet(of: workout) != nil else { return nil }
        let logged = workout.orderedExercises.flatMap(\.orderedSets).filter(\.isCompleted)
        let last = logged.max { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        guard let seconds = last?.restSeconds, seconds > 0 else { return nil }
        return seconds
    }
}
