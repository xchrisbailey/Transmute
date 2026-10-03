import Foundation
import SwiftData

/// Running a workout (#11). A session is a `Workout` with no end date: every change is made
/// on the model and saved straight away, so a killed app opens back into the same set with
/// the same rest still counting down.
public enum WorkoutSession {
    /// The session still going, if there is one. Only one runs at a time.
    public static func current(in context: ModelContext) throws -> Workout? {
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt == nil }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Starts a planned day: every exercise and set, prefilled so most sets are one tap.
    ///
    /// With a profile, targets come from the progression engine (#12): what was logged last
    /// time decides today's numbers, and each set records the target it was logged against.
    /// Its preferences (#18) fill in missing rests and decide whether warm-up sets appear.
    /// Without one, the plan's targets are used as written, and loads the plan leaves open come
    /// from the last time the exercise was done.
    @discardableResult
    public static func start(
        _ day: PlanDay, profile: Profile? = nil, library: ExerciseLibrary = .bundled, at date: Date = .now,
        in context: ModelContext
    ) -> Workout {
        let workout = Workout(title: day.focus, startedAt: date, planDay: day)
        context.insert(workout)
        for planned in day.orderedExercises {
            let logged = LoggedExercise(exerciseID: planned.exerciseID, order: planned.order)
            workout.exercises?.append(logged)
            if let profile {
                let history = (try? ProgressionEngine.history(of: planned.exerciseID, in: context, excluding: workout))
                let result = ProgressionEngine.next(
                    for: planned, history: history ?? [], profile: profile, library: library)
                for set in sets(for: planned, targets: result.targets, profile: profile, library: library) {
                    logged.sets?.append(set)
                }
            } else {
                let lastLoad = lastWorkingLoad(of: planned.exerciseID, before: date, in: context)
                for target in planned.orderedSets {
                    logged.sets?.append(prefilled(from: target, fallbackLoad: lastLoad))
                }
            }
        }
        save(context)
        return workout
    }

    /// Starts a workout off the plan, with nothing in it yet.
    @discardableResult
    public static func startAdHoc(title: String, at date: Date = .now, in context: ModelContext) -> Workout {
        let workout = Workout(title: title, startedAt: date)
        context.insert(workout)
        save(context)
        return workout
    }

    // MARK: Where you are

    /// The set to do next: the first unlogged set of the first exercise not skipped.
    public static func currentSet(of workout: Workout) -> LoggedSet? {
        for exercise in workout.orderedExercises where !exercise.isSkipped {
            if let set = exercise.orderedSets.first(where: { !$0.isCompleted }) {
                return set
            }
        }
        return nil
    }

    /// Seconds of rest left at a moment, or `nil` when no rest is running.
    public static func restRemaining(in workout: Workout, at date: Date = .now) -> TimeInterval? {
        guard let end = workout.restEndsAt else { return nil }
        let remaining = end.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    // MARK: Sets

    /// Checks a set off and starts its rest, unless it was the last set of the workout or the
    /// person turned auto-start off (#18). Returns the rest that started.
    ///
    /// `preferences` defaults to the stored profile's, so a set logged from the watch or a
    /// widget follows the same choice as one logged on the session screen.
    @discardableResult
    public static func complete(
        _ set: LoggedSet, in workout: Workout, at date: Date = .now, preferences: WorkoutPreferences? = nil
    ) -> TimeInterval? {
        set.complete(at: date)
        let autoStarts = (preferences ?? .stored(in: workout.modelContext)).autoStartRest
        let rest: TimeInterval? =
            if autoStarts, currentSet(of: workout) != nil, let seconds = set.restSeconds, seconds > 0 {
                seconds
            } else {
                nil
            }
        startRest(rest, in: workout, at: date)
        save(workout.modelContext)
        return rest
    }

    /// Takes a check back, e.g. after a mis-tap.
    public static func reopen(_ set: LoggedSet, in workout: Workout) {
        set.isCompleted = false
        set.completedAt = nil
        save(workout.modelContext)
    }

    /// Adds a set copying the last one's values and rest. With no set to copy, the rest is
    /// the profile's default.
    @discardableResult
    public static func addSet(to exercise: LoggedExercise) -> LoggedSet {
        let last = exercise.orderedSets.last
        let set = LoggedSet(
            order: exercise.orderedSets.count, weightKg: last?.weightKg, reps: last?.reps, seconds: last?.seconds,
            meters: last?.meters)
        set.rounds = last?.rounds
        set.restSeconds = last?.restSeconds ?? WorkoutPreferences.stored(in: exercise.modelContext).workingRestSeconds
        set.intervalRestSeconds = last?.intervalRestSeconds
        exercise.sets?.append(set)
        save(exercise.modelContext)
        return set
    }

    /// Removes a set that hasn't been logged.
    public static func remove(_ set: LoggedSet, from exercise: LoggedExercise) {
        guard !set.isCompleted, let context = exercise.modelContext else { return }
        exercise.sets?.removeAll { $0 === set }
        context.delete(set)
        for (index, set) in exercise.orderedSets.enumerated() {
            set.order = index
        }
        save(context)
    }

    // MARK: Rest

    /// Starts, replaces or (with `nil`) clears the rest timer.
    public static func startRest(_ seconds: TimeInterval?, in workout: Workout, at date: Date = .now) {
        workout.restSeconds = seconds
        workout.restEndsAt = seconds.map { date.addingTimeInterval($0) }
        save(workout.modelContext)
    }

    /// Adds or takes away rest from the running timer, never below zero.
    public static func adjustRest(by seconds: TimeInterval, in workout: Workout, at date: Date = .now) {
        guard let remaining = restRemaining(in: workout, at: date) else { return }
        let new = max(0, remaining + seconds)
        workout.restEndsAt = date.addingTimeInterval(new)
        workout.restSeconds = max(new, (workout.restSeconds ?? 0) + seconds)
        if new == 0 { workout.restEndsAt = nil }
        save(workout.modelContext)
    }

    // MARK: Exercises

    /// Passes over an exercise, or brings it back.
    public static func setSkipped(_ exercise: LoggedExercise, _ isSkipped: Bool) {
        exercise.isSkipped = isSkipped
        save(exercise.modelContext)
    }

    /// Swaps in another exercise. Logged sets stay with the one they were done on, so only
    /// unlogged sets move across; their loads clear, since another movement needs its own.
    @discardableResult
    public static func substitute(
        _ exercise: LoggedExercise, with replacement: LibraryExercise, in workout: Workout,
        library: ExerciseLibrary = .bundled
    ) -> LoggedExercise {
        let context = workout.modelContext
        let open = exercise.orderedSets.filter { !$0.isCompleted }
        let sameTracking = library.exercise(id: exercise.exerciseID)?.tracking == replacement.tracking
        guard exercise.orderedSets.contains(where: \.isCompleted) else {
            // Nothing logged yet: change it in place.
            exercise.substitutedFromID = exercise.substitutedFromID ?? exercise.exerciseID
            exercise.exerciseID = replacement.id
            reset(open, keepingValues: sameTracking, for: replacement.tracking)
            save(context)
            return exercise
        }
        let substitute = LoggedExercise(exerciseID: replacement.id, order: exercise.order + 1)
        substitute.substitutedFromID = exercise.exerciseID
        for later in workout.orderedExercises where later.order > exercise.order {
            later.order += 1
        }
        workout.exercises?.append(substitute)
        for (index, set) in open.enumerated() {
            exercise.sets?.removeAll { $0 === set }
            set.order = index
            substitute.sets?.append(set)
        }
        reset(open, keepingValues: sameTracking, for: replacement.tracking)
        save(context)
        return substitute
    }

    /// Adds an exercise at the end with three sets.
    @discardableResult
    public static func add(_ exercise: LibraryExercise, to workout: Workout, sets count: Int = 3) -> LoggedExercise {
        let logged = LoggedExercise(exerciseID: exercise.id, order: (workout.orderedExercises.last?.order ?? -1) + 1)
        workout.exercises?.append(logged)
        let lastLoad = workout.modelContext.flatMap {
            lastWorkingLoad(of: exercise.id, before: workout.startedAt, in: $0)
        }
        let rest = WorkoutPreferences.stored(in: workout.modelContext).workingRestSeconds
        for index in 0..<count {
            let set = defaultSet(for: exercise.tracking, order: index, rest: rest)
            if exercise.tracking == .weightReps { set.weightKg = lastLoad }
            logged.sets?.append(set)
        }
        save(workout.modelContext)
        return logged
    }

    // MARK: Ending

    /// Ends the session: unlogged sets go, as do exercises left with nothing logged, and the
    /// rest timer stops. Returns the summary for the finish screen.
    @discardableResult
    public static func finish(_ workout: Workout, at date: Date = .now) -> WorkoutSummary {
        let context = workout.modelContext
        for exercise in workout.orderedExercises {
            for set in exercise.orderedSets where !set.isCompleted {
                exercise.sets?.removeAll { $0 === set }
                context?.delete(set)
            }
            if exercise.orderedSets.isEmpty {
                workout.exercises?.removeAll { $0 === exercise }
                context?.delete(exercise)
            }
        }
        workout.endedAt = date
        workout.restEndsAt = nil
        workout.restSeconds = nil
        save(context)
        return WorkoutSummary(workout)
    }

    /// Throws the session away without logging anything.
    public static func discard(_ workout: Workout, in context: ModelContext) {
        context.delete(workout)
        save(context)
    }

    // MARK: Helpers

    static func prefilled(from target: PlannedSet, fallbackLoad: Double?) -> LoggedSet {
        let set = LoggedSet(
            order: target.order, weightKg: target.targetLoadKg ?? (target.targetReps != nil ? fallbackLoad : nil),
            reps: target.targetReps, seconds: target.targetSeconds, meters: target.targetMeters)
        set.rounds = target.rounds
        set.intervalRestSeconds = target.intervalRestSeconds
        set.restSeconds = target.restSeconds
        set.isWarmUp = target.isWarmUp
        return set
    }

    /// A set with the usual starting numbers. `rest` is the rest between sets of reps, which
    /// the profile sets; timed and distance work keep their own shorter rests.
    static func defaultSet(for tracking: TrackingType, order: Int, rest: Double = 90) -> LoggedSet {
        let set = LoggedSet(order: order)
        switch tracking {
        case .weightReps, .reps:
            set.reps = 10
            set.restSeconds = rest
        case .time:
            set.seconds = 30
            set.restSeconds = 45
        case .distanceTime:
            set.meters = 20
            set.restSeconds = 60
        case .intervals:
            set.seconds = 20
            set.rounds = 8
            set.intervalRestSeconds = 10
            set.restSeconds = 60
        }
        return set
    }

    private static func reset(_ sets: [LoggedSet], keepingValues: Bool, for tracking: TrackingType) {
        for set in sets {
            if keepingValues {
                set.weightKg = nil
            } else {
                let fresh = defaultSet(for: tracking, order: set.order)
                (set.weightKg, set.reps, set.seconds, set.meters) = (nil, fresh.reps, fresh.seconds, fresh.meters)
                (set.rounds, set.intervalRestSeconds) = (fresh.rounds, fresh.intervalRestSeconds)
                set.restSeconds = set.restSeconds ?? fresh.restSeconds
            }
        }
    }

    /// The load of the last logged working set of an exercise, for prefilling.
    static func lastWorkingLoad(of exerciseID: String, before date: Date, in context: ModelContext) -> Double? {
        let descriptor = FetchDescriptor<LoggedSet>(
            predicate: #Predicate { set in
                set.isCompleted && !set.isWarmUp && set.weightKg != nil
            },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        let sets = (try? context.fetch(descriptor)) ?? []
        return sets.first { set in
            set.exercise?.exerciseID == exerciseID && (set.completedAt ?? .distantFuture) < date
        }?.weightKg
    }

    static func save(_ context: ModelContext?) {
        try? context?.save()
    }
}

/// What the finish screen shows: "The work is done. 18 sets, 8,420 kg moved."
public struct WorkoutSummary: Hashable, Sendable {
    public var sets: Int
    public var exercises: Int
    public var volumeKg: Double
    public var duration: TimeInterval

    public init(sets: Int, exercises: Int, volumeKg: Double, duration: TimeInterval) {
        self.sets = sets
        self.exercises = exercises
        self.volumeKg = volumeKg
        self.duration = duration
    }

    public init(_ workout: Workout, now: Date = .now) {
        let logged = workout.orderedExercises.flatMap(\.orderedSets).filter { $0.isCompleted && !$0.isWarmUp }
        self.init(
            sets: logged.count,
            exercises: workout.orderedExercises.filter { $0.orderedSets.contains(where: \.isCompleted) }.count,
            volumeKg: workout.volumeKg, duration: (workout.endedAt ?? now).timeIntervalSince(workout.startedAt))
    }
}
