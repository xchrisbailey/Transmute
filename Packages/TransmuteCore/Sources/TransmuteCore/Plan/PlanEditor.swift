import Foundation
import SwiftData

/// Hand edits to a plan (#10). Each marks the day edited so a rebrew keeps it, and leaves the
/// plan ordered and consistent. Undo comes from the model context's undo manager.
public enum PlanEditor {
    /// The week a date falls in, counting from the plan's start, clamped to the plan.
    public static func week(of plan: Plan, on date: Date = .now, calendar: Calendar = .init(identifier: .iso8601))
        -> Int
    {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: plan.startDate), to: date).day ?? 0
        return min(max(days / 7 + 1, 1), max(plan.weekCount, 1))
    }

    /// The calendar date of a plan day.
    public static func date(of day: PlanDay, in plan: Plan, calendar: Calendar = .init(identifier: .iso8601)) -> Date {
        let start = calendar.dateInterval(of: .weekOfYear, for: plan.startDate)?.start ?? plan.startDate
        return calendar.date(byAdding: .day, value: (day.week - 1) * 7 + day.weekday - 1, to: start) ?? start
    }

    // MARK: Days

    /// The session on a weekday of a week, if there is one.
    public static func day(of plan: Plan, week: Int, weekday: Weekday) -> PlanDay? {
        plan.days?.first { $0.week == week && $0.weekday == weekday }
    }

    /// Moves a day to another weekday in its week. If that weekday already has a session, the
    /// two swap.
    public static func move(_ day: PlanDay, to weekday: Weekday) {
        guard weekday != day.weekday, (1...7).contains(weekday) else { return }
        if let other = day.plan?.days?.first(where: { $0.week == day.week && $0.weekday == weekday }) {
            other.weekday = day.weekday
            other.isEdited = true
        }
        day.weekday = weekday
        day.isEdited = true
    }

    // MARK: Exercises

    /// Adds an exercise at the end with sets copied from a sensible default for its tracking.
    @discardableResult
    public static func add(_ exercise: LibraryExercise, to day: PlanDay, sets count: Int = 3) -> PlannedExercise {
        let planned = PlannedExercise(exerciseID: exercise.id, order: day.orderedExercises.count)
        for index in 0..<count {
            planned.sets?.append(defaultSet(for: exercise.tracking, order: index))
        }
        day.exercises?.append(planned)
        day.isEdited = true
        return planned
    }

    public static func remove(_ exercise: PlannedExercise, from day: PlanDay, in context: ModelContext) {
        day.exercises?.removeAll { $0 === exercise }
        context.delete(exercise)
        renumber(day)
        day.isEdited = true
    }

    /// Reorders like `List.onMove`.
    public static func move(in day: PlanDay, from source: IndexSet, to destination: Int) {
        var ordered = day.orderedExercises
        let moving = source.map { ordered[$0] }
        let target = destination - source.filter { $0 < destination }.count
        for index in source.reversed() { ordered.remove(at: index) }
        ordered.insert(contentsOf: moving, at: target)
        for (index, exercise) in ordered.enumerated() {
            exercise.order = index
        }
        day.isEdited = true
    }

    /// Moves an exercise to a position in a day: its own day to reorder, or another day in the
    /// plan. `index` is where it ends up in that day's order; without one it goes last. Both
    /// days stay numbered from zero. Moving to another day takes the exercise out of its
    /// superset, since its partner stays behind.
    public static func move(_ exercise: PlannedExercise, to day: PlanDay, at index: Int? = nil) {
        guard let source = exercise.day else { return }
        var ordered = day.orderedExercises.filter { $0 !== exercise }
        let position = min(max(index ?? ordered.count, 0), ordered.count)
        if source === day, exercise.order == position { return }
        if source !== day {
            exercise.day = day
            exercise.supersetGroup = nil
            source.isEdited = true
        }
        ordered.insert(exercise, at: position)
        for (index, exercise) in ordered.enumerated() {
            exercise.order = index
        }
        if source !== day { renumber(source) }
        day.isEdited = true
    }

    /// Replaces the exercise, keeping its sets when the tracking matches and resetting them
    /// to defaults when it doesn't. Loads are cleared, since another movement needs its own.
    public static func swap(
        _ planned: PlannedExercise, for exercise: LibraryExercise, library: ExerciseLibrary = .bundled
    ) {
        let old = library.exercise(id: planned.exerciseID)
        planned.exerciseID = exercise.id
        planned.notes = ""
        if old?.tracking == exercise.tracking {
            for set in planned.sets ?? [] {
                set.targetLoadKg = nil
                set.targetPercentOneRepMax = nil
            }
        } else {
            let count = max(1, planned.sets?.count ?? 3)
            for set in planned.sets ?? [] {
                planned.modelContext?.delete(set)
            }
            planned.sets = (0..<count).map { defaultSet(for: exercise.tracking, order: $0) }
        }
        planned.day?.isEdited = true
    }

    /// Exercises that could stand in: same movement pattern and category, doable with the kit,
    /// with the library's easier and harder variants first.
    public static func alternatives(
        to exerciseID: String, equipment: Set<Equipment>, library: ExerciseLibrary = .bundled
    ) -> [LibraryExercise] {
        guard let exercise = library.exercise(id: exerciseID) else { return [] }
        let similar = library.search(
            ExerciseQuery(categories: [exercise.category], patterns: [exercise.pattern], availableEquipment: equipment)
        ).filter { $0.id != exercise.id }
        let variants = [exercise.easier, exercise.harder].compactMap { $0 }
        return similar.sorted { lhs, rhs in
            (variants.contains(lhs.id) ? 0 : 1) < (variants.contains(rhs.id) ? 0 : 1)
        }
    }

    // MARK: Sets

    /// Adds a set copying the last one's targets.
    public static func addSet(to planned: PlannedExercise) {
        let ordered = planned.orderedSets
        let set = PlannedSet(order: ordered.count)
        if let last = ordered.last {
            set.targetReps = last.targetReps
            set.targetRepsMax = last.targetRepsMax
            set.targetSeconds = last.targetSeconds
            set.targetMeters = last.targetMeters
            set.targetLoadKg = last.targetLoadKg
            set.targetPercentOneRepMax = last.targetPercentOneRepMax
            set.targetRPE = last.targetRPE
            set.restSeconds = last.restSeconds
            set.rounds = last.rounds
            set.intervalRestSeconds = last.intervalRestSeconds
        }
        planned.sets?.append(set)
        planned.day?.isEdited = true
    }

    /// Removes the last set, keeping at least one.
    public static func removeSet(from planned: PlannedExercise, in context: ModelContext) {
        let ordered = planned.orderedSets
        guard ordered.count > 1, let last = ordered.last else { return }
        planned.sets?.removeAll { $0 === last }
        context.delete(last)
        planned.day?.isEdited = true
    }

    /// Sets how many sets an exercise has: new ones copy the last, extra ones come off the end,
    /// and at least one stays.
    public static func setSetCount(of planned: PlannedExercise, to count: Int, in context: ModelContext) {
        let target = max(1, count)
        for _ in 0..<max(0, target - planned.orderedSets.count) {
            addSet(to: planned)
        }
        for _ in 0..<max(0, planned.orderedSets.count - target) {
            removeSet(from: planned, in: context)
        }
    }

    /// Marks a day edited after its targets were changed in place.
    public static func touched(_ planned: PlannedExercise) {
        planned.day?.isEdited = true
    }

    // MARK: Plans

    /// Makes one plan active and archives the rest.
    public static func activate(_ plan: Plan, in context: ModelContext) throws {
        for other in try context.fetch(FetchDescriptor<Plan>()) {
            other.isActive = other === plan
        }
    }

    // MARK: Helpers

    static func defaultSet(for tracking: TrackingType, order: Int) -> PlannedSet {
        let set = PlannedSet(order: order)
        switch tracking {
        case .weightReps, .reps:
            set.targetReps = 10
            set.restSeconds = 90
        case .time:
            set.targetSeconds = 30
            set.restSeconds = 45
        case .distanceTime:
            set.targetMeters = 20
            set.restSeconds = 60
        case .intervals:
            set.targetSeconds = 20
            set.rounds = 8
            set.intervalRestSeconds = 10
            set.restSeconds = 60
        }
        return set
    }

    static func renumber(_ day: PlanDay) {
        for (index, exercise) in day.orderedExercises.enumerated() {
            exercise.order = index
        }
    }
}
