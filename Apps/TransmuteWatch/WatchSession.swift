import Foundation
import Observation
import SwiftData
import TransmuteCore

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

/// The workout running on the watch. Screens draw its snapshot and send it commands, so
/// they don't care whether the workout lives in this watch's store or is mirrored from the
/// iPhone.
@MainActor @Observable
final class WatchSession: Identifiable {
    /// Who runs the workout: this watch, which has it in its store, or the iPhone.
    private enum Ownership {
        case owned(Workout)
        case mirrored
    }

    let id: UUID
    /// Set once the workout is finished, for the summary.
    private(set) var summary: WorkoutSummary?
    private(set) var isDiscarded = false
    var record: RecordNotice?
    /// A logged set far beyond the previous best, waiting for a yes or a fix.
    var suspicious: SetRef?

    let live: WatchLiveWorkout
    let link: SessionLink
    private(set) var isSavedToHealth = false

    let library: ExerciseLibrary
    private let ownership: Ownership
    private let context: ModelContext
    private let health: any HealthService
    private var own: SessionSnapshot
    private var isEnding = false

    init(
        workout: Workout, context: ModelContext, library: ExerciseLibrary, link: SessionLink = WatchLive.link,
        live: WatchLiveWorkout = WatchLive.workout, health: any HealthService
    ) {
        id = workout.id
        ownership = .owned(workout)
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
        ownership = .mirrored
        self.context = context
        self.library = library
        self.live = live
        self.link = link
        self.health = health
        own = snapshot
    }

    private var ownedWorkout: Workout? {
        if case .owned(let workout) = ownership { workout } else { nil }
    }

    var snapshot: SessionSnapshot {
        if case .mirrored = ownership, let mirrored = link.mirrored, mirrored.workoutID == id { return mirrored }
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
        guard let workout = ownedWorkout else {
            link.send(command)
            return
        }
        let outcome = SessionMirror.apply(command, to: workout, in: context)
        applied(command, outcome, fromPhone: false)
        if outcome == .discarded {
            link.discarded()
        } else {
            Task {
                await live.ensureMirroring()
                link.publish()
            }
        }
    }

    /// The iPhone's session moved on. Finishing or discarding there ends the Health workout
    /// here, since the watch is the one recording it.
    func mirrorChanged() {
        guard case .mirrored = ownership, !isEnding else { return }
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
            // The iPhone hears the Health id before this watch's session ends, while the mirror
            // can still carry it.
            let healthID = try? await live.finish(
                workoutID: mirrored.workoutID, title: mirrored.title, at: mirrored.endedAt ?? .now,
                beforeEnding: { [link] healthID in
                    await link.ended(workoutID: mirrored.workoutID, healthWorkoutID: healthID)
                })
            isSavedToHealth = healthID != nil
        }
    }

    func close() {
        if case .mirrored = ownership { link.dismissMirrored() }
    }

    func confirmSuspicious() {
        guard let ref = suspicious, let set = set(at: ref) else { return }
        suspicious = nil
        guard let check = try? RecordBook(context: context, library: library).confirm(set) else { return }
        try? context.save()
        record = check.gold.first.map { RecordNotice(mark: $0.mark) }
    }

    func fixSuspicious() {
        guard let ref = suspicious else { return }
        suspicious = nil
        perform(.startRest(seconds: nil, at: .now))
        perform(.reopenSet(ref))
    }

    private func applied(_ command: SessionCommand, _ outcome: SessionMirror.Outcome, fromPhone: Bool) {
        guard let workout = ownedWorkout else { return }
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
        ownedWorkout?.orderedExercises.first { $0.order == ref.exerciseOrder }?
            .orderedSets.first { $0.order == ref.setOrder }
    }
}

extension SessionSnapshot {
    func exercise(at ref: SetRef) -> Exercise? {
        exercise(order: ref.exerciseOrder)
    }
}

extension WorkoutSummary {
    init(_ snapshot: SessionSnapshot) {
        let logged = snapshot.exercises.flatMap(\.sets).filter(\.isCompleted)
        self.init(
            sets: logged.filter { !$0.isWarmUp }.count,
            exercises: snapshot.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count,
            volumeKg: logged.reduce(0) { $0 + ($1.weightKg ?? 0) * Double($1.reps ?? 0) },
            duration: (snapshot.endedAt ?? .now).timeIntervalSince(snapshot.startedAt))
    }
}
