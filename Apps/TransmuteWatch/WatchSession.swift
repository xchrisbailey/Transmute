import Foundation
import Observation
import SwiftData
import TransmuteCore

/// A record just set, for the toast.
struct RecordNotice: Equatable, Identifiable {
    let id = UUID()
    let mark: RecordMark
}

/// The live workout and the link to the iPhone, shared by the app delegate (which the iPhone
/// wakes to start a workout) and the screens.
@MainActor
enum WatchLive {
    static let workout = WatchLiveWorkout()
    static let link = SessionLink(live: workout, device: .watch)
}

/// The workout running on the watch (#15). Screens draw its snapshot and send it commands, so
/// they don't care whether the workout lives in this watch's store or is mirrored from the
/// iPhone.
@MainActor @Observable
final class WatchSession: Identifiable {
    let id: UUID
    /// Set once the workout is finished, for the summary.
    private(set) var summary: WorkoutSummary?
    private(set) var isDiscarded = false
    var record: RecordNotice?
    /// A logged set far beyond the previous best, waiting for a yes or a fix.
    var suspicious: SetRef?

    /// The Health workout running alongside: heart rate and energy while it lasts.
    let live: WatchLiveWorkout
    let link: SessionLink
    /// True once the finished workout is in Health.
    private(set) var isSavedToHealth = false

    let library: ExerciseLibrary
    /// The workout in this watch's store, or `nil` when the iPhone is running it.
    private let workout: Workout?
    private let context: ModelContext
    private let health: any HealthService
    private var own: SessionSnapshot
    private var isEnding = false

    /// A workout this watch runs and saves.
    init(
        workout: Workout, context: ModelContext, library: ExerciseLibrary, link: SessionLink = WatchLive.link,
        live: WatchLiveWorkout = WatchLive.workout, health: any HealthService
    ) {
        id = workout.id
        self.workout = workout
        self.context = context
        self.library = library
        self.live = live
        self.link = link
        self.health = health
        own = SessionSnapshot(workout, library: library)
        link.own(workout, in: context, library: library)
        link.onCommand = { [weak self] command, outcome in
            self?.applied(command, outcome, fromPhone: true)
        }
    }

    /// A workout the iPhone runs: this watch shows it, logs to it and records the heart rate.
    init(
        mirroring snapshot: SessionSnapshot, context: ModelContext, library: ExerciseLibrary,
        link: SessionLink = WatchLive.link, live: WatchLiveWorkout = WatchLive.workout, health: any HealthService
    ) {
        id = snapshot.workoutID
        workout = nil
        self.context = context
        self.library = library
        self.live = live
        self.link = link
        self.health = health
        own = snapshot
    }

    /// The session as it stands: this watch's own workout, or the iPhone's latest snapshot.
    var snapshot: SessionSnapshot {
        if workout == nil, let mirrored = link.mirrored, mirrored.workoutID == id { return mirrored }
        return own
    }

    /// Starts the Health workout, or picks it back up after a relaunch. Logging works without
    /// it: with no Health access there's just no heart rate, and nothing is saved to Health.
    func startLive() async {
        guard health.isAvailable, !snapshot.isFinished else { return }
        if await live.recover() { return }
        try? await health.requestAccess(.workouts)
        let exercises = snapshot.exercises.compactMap { library.exercise(id: $0.exerciseID) }
        try? await live.start(activity: .infer(from: exercises), at: .now)
        link.publish()
    }

    func perform(_ command: SessionCommand) {
        guard let workout else {
            link.send(command)
            return
        }
        let outcome = SessionMirror.apply(command, to: workout, in: context)
        applied(command, outcome, fromPhone: false)
        if outcome == .discarded {
            link.discarded()
        } else {
            // Reconnects first if the iPhone dropped off; a no-op while it's connected.
            Task {
                await live.startMirroring()
                link.publish()
            }
        }
    }

    /// The iPhone's session moved on. Finishing or discarding there ends the Health workout
    /// here, since the watch is the one recording it.
    func mirrorChanged() {
        guard workout == nil, !isEnding else { return }
        guard let mirrored = link.mirrored, mirrored.workoutID == id else {
            isEnding = true
            isDiscarded = true
            Task { await live.discard() }
            return
        }
        own = mirrored
        guard mirrored.isFinished else { return }
        isEnding = true
        summary = WorkoutSummary(mirrored)
        Task {
            let healthID = try? await live.finish(
                workoutID: mirrored.workoutID, title: mirrored.title, at: mirrored.endedAt ?? .now)
            isSavedToHealth = healthID != nil
            link.ended(workoutID: mirrored.workoutID, healthWorkoutID: healthID)
        }
    }

    /// Closes the summary of a workout the iPhone ran.
    func close() {
        if workout == nil { link.dismissMirrored() }
    }

    /// The person said the big jump is real: record it.
    func confirmSuspicious() {
        guard let ref = suspicious, let set = set(at: ref) else { return }
        suspicious = nil
        guard let check = try? RecordBook(context: context, library: library).confirm(set) else { return }
        try? context.save()
        record = check.gold.first.map { RecordNotice(mark: $0.mark) }
    }

    /// The person said it was a slip: open the set back up to correct it.
    func fixSuspicious() {
        guard let ref = suspicious else { return }
        suspicious = nil
        perform(.startRest(seconds: nil, at: .now))
        perform(.reopenSet(ref))
    }

    // MARK: Owning

    private func applied(_ command: SessionCommand, _ outcome: SessionMirror.Outcome, fromPhone: Bool) {
        guard let workout else { return }
        switch outcome {
        case .ignored:
            break
        case .discarded:
            isDiscarded = true
            Task { await live.discard() }
            return
        case .finished(let summary):
            self.summary = summary
            Task { await saveToHealth(workout) }
        case .applied:
            switch command {
            case .logSet(let ref, _, _): checkRecords(ref, asks: !fromPhone)
            case .reopenSet(let ref): recomputeRecords(ref)
            default: break
            }
        }
        own = SessionSnapshot(workout, library: library)
    }

    /// Ends the Health workout and keeps its id on the logged workout, so the iPhone doesn't
    /// save a second one and deleting the workout later removes it from Health too.
    private func saveToHealth(_ workout: Workout) async {
        guard let id = try? await live.finish(workoutID: workout.id, title: workout.title, at: workout.endedAt ?? .now)
        else { return }
        workout.healthKitWorkoutID = id
        try? context.save()
        isSavedToHealth = true
    }

    private func checkRecords(_ ref: SetRef, asks: Bool) {
        guard let set = set(at: ref),
            let check = try? RecordBook(context: context, library: library).check(set)
        else { return }
        try? context.save()
        if let gold = check.gold.first {
            record = RecordNotice(mark: gold.mark)
        } else if asks, !check.needsConfirmation.isEmpty {
            suspicious = ref
        }
    }

    private func recomputeRecords(_ ref: SetRef) {
        guard let exerciseID = set(at: ref)?.exercise?.exerciseID else { return }
        _ = try? RecordBook(context: context, library: library).recompute(exerciseID: exerciseID)
        try? context.save()
    }

    private func set(at ref: SetRef) -> LoggedSet? {
        workout?.orderedExercises.first { $0.order == ref.exerciseOrder }?
            .orderedSets.first { $0.order == ref.setOrder }
    }
}

extension SessionSnapshot {
    func exercise(at ref: SetRef) -> Exercise? {
        exercise(order: ref.exerciseOrder)
    }
}

extension WorkoutSummary {
    /// The summary of a workout the iPhone ran, from its last snapshot.
    init(_ snapshot: SessionSnapshot) {
        let logged = snapshot.exercises.flatMap(\.sets).filter(\.isCompleted)
        self.init(
            sets: logged.filter { !$0.isWarmUp }.count,
            exercises: snapshot.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count,
            volumeKg: logged.reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) },
            duration: (snapshot.endedAt ?? .now).timeIntervalSince(snapshot.startedAt))
    }
}
