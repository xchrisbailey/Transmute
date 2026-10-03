import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct SessionMirrorTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let first = SetRef(exerciseOrder: 0, setOrder: 0)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// This week's Monday session from the sample plan, just started.
    func session() throws -> Workout {
        let (_, plan) = SampleData.insert(into: context, now: now)
        try context.save()
        let day = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        return WorkoutSession.start(day, at: now, in: context)
    }

    /// Applies a command on both sides and checks the mirror's guess is what the owner made.
    @discardableResult
    func expectSame(
        _ command: SessionCommand, on workout: Workout, _ expected: SessionMirror.Outcome = .applied,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> SessionSnapshot {
        let guess = SessionSnapshot(workout).applying(command)
        let outcome = SessionMirror.apply(command, to: workout, in: context)
        #expect(outcome == expected, sourceLocation: sourceLocation)
        let truth = SessionSnapshot(workout)
        #expect(guess == truth, "\(command)", sourceLocation: sourceLocation)
        return truth
    }

    // MARK: Snapshot

    @Test func aSnapshotCarriesTheWorkout() throws {
        let workout = try session()
        workout.orderedExercises[1].isSkipped = true
        WorkoutSession.startRest(90, in: workout, at: now)
        let snapshot = SessionSnapshot(workout)

        #expect(snapshot.workoutID == workout.id)
        #expect(snapshot.title == "Lower and power")
        #expect(snapshot.startedAt == now)
        #expect(snapshot.endedAt == nil)
        #expect(!snapshot.isFinished)
        #expect(snapshot.restSeconds == 90)
        #expect(snapshot.restEndsAt == now.addingTimeInterval(90))
        #expect(snapshot.exercises.map(\.exerciseID) == workout.orderedExercises.map(\.exerciseID))
        #expect(snapshot.exercises.map(\.order) == workout.orderedExercises.map(\.order))
        #expect(snapshot.exercises.map(\.isSkipped) == workout.orderedExercises.map(\.isSkipped))

        let squat = try #require(snapshot.exercises.first { $0.exerciseID == "back-squat" })
        let logged = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        #expect(squat.name == ExerciseLibrary.bundled.exercise(id: "back-squat")?.name)
        #expect(squat.tracking == .weightReps)
        #expect(squat.sets.map(\.order) == logged.orderedSets.map(\.order))
        #expect(squat.sets.map(\.weightKg) == logged.orderedSets.map(\.weightKg))
        #expect(squat.sets.allSatisfy { $0.reps == 5 && $0.restSeconds == 150 && !$0.isCompleted })
    }

    @Test func anExerciseTheLibraryDoesNotKnowKeepsItsID() throws {
        let workout = WorkoutSession.startAdHoc(title: "Odd", at: now, in: context)
        workout.exercises?.append(LoggedExercise(exerciseID: "custom-sled-drag", order: 0))
        let exercise = try #require(SessionSnapshot(workout).exercises.first)
        #expect(exercise.name == "custom-sled-drag")
        #expect(exercise.tracking == nil)
    }

    @Test func currentFollowsTheSessionsCurrentSet() throws {
        let workout = try session()
        func expectParity(sourceLocation: SourceLocation = #_sourceLocation) {
            let snapshot = SessionSnapshot(workout)
            let set = WorkoutSession.currentSet(of: workout)
            let ref = set.flatMap { set in
                set.exercise.map { SetRef(exerciseOrder: $0.order, setOrder: set.order) }
            }
            #expect(snapshot.current == ref, sourceLocation: sourceLocation)
            #expect(snapshot.currentExercise?.exerciseID == set?.exercise?.exerciseID, sourceLocation: sourceLocation)
            #expect(snapshot.currentSet == set.map(SessionSnapshot.Set.init), sourceLocation: sourceLocation)
        }

        expectParity()
        #expect(SessionSnapshot(workout).current == first)
        let set = try #require(WorkoutSession.currentSet(of: workout))
        WorkoutSession.complete(set, in: workout, at: now)
        expectParity()
        WorkoutSession.setSkipped(workout.orderedExercises[0], true)
        expectParity()
        #expect(SessionSnapshot(workout).currentExercise?.exerciseID == "back-squat")
        for exercise in workout.orderedExercises {
            WorkoutSession.setSkipped(exercise, true)
        }
        expectParity()
        #expect(SessionSnapshot(workout).current == nil)
    }

    @Test func restRemainingMatchesTheSession() throws {
        let workout = try session()
        #expect(SessionSnapshot(workout).restRemaining(at: now) == nil)
        WorkoutSession.startRest(90, in: workout, at: now)
        let snapshot = SessionSnapshot(workout)
        for offset in [0.0, 30, 89.5, 90, 200] {
            let date = now.addingTimeInterval(offset)
            #expect(snapshot.restRemaining(at: date) == WorkoutSession.restRemaining(in: workout, at: date))
        }
        #expect(snapshot.restRemaining(at: now.addingTimeInterval(30)) == 60)
        #expect(snapshot.restRemaining(at: now.addingTimeInterval(90)) == nil)
    }

    @Test func startedOnIsStoredOnTheWorkout() throws {
        let workout = try session()
        #expect(workout.startedOn == nil)
        workout.startedOn = .watch
        try context.save()
        #expect(workout.startedOnRaw == "watch")
        #expect(try WorkoutSession.current(in: context)?.startedOn == .watch)
        workout.startedOnRaw = "toaster"
        #expect(workout.startedOn == nil)
    }

    // MARK: Owner and mirror agree

    @Test func loggingASetWritesItsValuesAndStartsTheRest() throws {
        let workout = try session()
        let values = SetValues(weightKg: 42.5, reps: 7, rpe: 8)
        let snapshot = expectSame(.logSet(first, values, at: now.addingTimeInterval(60)), on: workout)

        let set = try #require(workout.orderedExercises.first?.orderedSets.first)
        #expect(set.isCompleted)
        #expect(set.completedAt == now.addingTimeInterval(60))
        #expect(set.weightKg == 42.5)
        #expect(set.reps == 7)
        #expect(set.rpe == 8)
        let rest = try #require(set.restSeconds)
        #expect(snapshot.restSeconds == rest)
        #expect(snapshot.restEndsAt == now.addingTimeInterval(60 + rest))
        #expect(snapshot.current == SetRef(exerciseOrder: 0, setOrder: 1))
    }

    @Test func loggingTheLastOpenSetStartsNoRest() throws {
        let workout = try session()
        let exercises = workout.orderedExercises
        for exercise in exercises.dropFirst() {
            WorkoutSession.setSkipped(exercise, true)
        }
        let sets = exercises[0].orderedSets
        for set in sets.dropLast() {
            expectSame(.logSet(SetRef(exerciseOrder: 0, setOrder: set.order), SetValues(reps: 5), at: now), on: workout)
        }
        #expect(workout.restEndsAt != nil)
        let last = SetRef(exerciseOrder: 0, setOrder: try #require(sets.last).order)
        let snapshot = expectSame(.logSet(last, SetValues(reps: 5), at: now), on: workout)
        #expect(snapshot.current == nil)
        #expect(snapshot.restEndsAt == nil)
        #expect(snapshot.restSeconds == nil)
    }

    @Test func loggingASetTwiceDoesNothingTheSecondTime() throws {
        let workout = try session()
        expectSame(.logSet(first, SetValues(weightKg: 40, reps: 5), at: now), on: workout)
        let before = SessionSnapshot(workout)

        let later = now.addingTimeInterval(45)
        let after = expectSame(.logSet(first, SetValues(weightKg: 99, reps: 1), at: later), on: workout, .ignored)
        #expect(after == before)
        #expect(after.set(at: first)?.weightKg == 40)
        #expect(after.set(at: first)?.completedAt == now)
        #expect(after.restEndsAt == before.restEndsAt)
    }

    @Test func reopeningAndUpdatingASet() throws {
        let workout = try session()
        expectSame(.reopenSet(first), on: workout, .ignored)
        expectSame(.logSet(first, SetValues(reps: 5), at: now), on: workout)
        let reopened = expectSame(.reopenSet(first), on: workout)
        #expect(reopened.set(at: first)?.isCompleted == false)
        #expect(reopened.set(at: first)?.completedAt == nil)
        #expect(reopened.current == first)

        let values = SetValues(weightKg: 20, reps: 12, seconds: 30, meters: 100, rpe: 6.5)
        let updated = expectSame(.updateSet(first, values), on: workout)
        #expect(updated.set(at: first).map(SetValues.init) == values)
        #expect(updated.set(at: first)?.isCompleted == false)
        // Values replace: what the command leaves out is cleared.
        let cleared = expectSame(.updateSet(first, SetValues(reps: 3)), on: workout)
        #expect(cleared.set(at: first).map(SetValues.init) == SetValues(reps: 3))
    }

    @Test func startingSkippingAndAdjustingTheRest() throws {
        let workout = try session()
        expectSame(.adjustRest(by: 15, at: now), on: workout, .ignored)

        let started = expectSame(.startRest(seconds: 120, at: now), on: workout)
        #expect(started.restRemaining(at: now) == 120)
        let longer = expectSame(.adjustRest(by: 30, at: now.addingTimeInterval(20.25)), on: workout)
        #expect(longer.restRemaining(at: now.addingTimeInterval(20.25)) == 129.75)
        #expect(longer.restSeconds == 150)
        let shorter = expectSame(.adjustRest(by: -15, at: now.addingTimeInterval(40)), on: workout)
        #expect(shorter.restRemaining(at: now.addingTimeInterval(40)) == 95)
        let gone = expectSame(.adjustRest(by: -500, at: now.addingTimeInterval(50)), on: workout)
        #expect(gone.restEndsAt == nil)
        // The rest ran out on its own: nothing left to adjust.
        expectSame(.startRest(seconds: 10, at: now), on: workout)
        expectSame(.adjustRest(by: 15, at: now.addingTimeInterval(10)), on: workout, .ignored)

        let skipped = expectSame(.startRest(seconds: nil, at: now), on: workout)
        #expect(skipped.restEndsAt == nil)
        #expect(skipped.restSeconds == nil)
    }

    @Test func skippingAnExerciseAndBringingItBack() throws {
        let workout = try session()
        let skipped = expectSame(.setSkipped(exerciseOrder: 0, true), on: workout)
        #expect(skipped.exercises[0].isSkipped)
        #expect(skipped.current?.exerciseOrder == 1)
        let back = expectSame(.setSkipped(exerciseOrder: 0, false), on: workout)
        #expect(back.current == first)
    }

    @Test func staleRefsAreIgnored() throws {
        let workout = try session()
        let before = SessionSnapshot(workout)
        let noExercise = SetRef(exerciseOrder: 99, setOrder: 0)
        let noSet = SetRef(exerciseOrder: 0, setOrder: 99)
        let commands: [SessionCommand] = [
            .logSet(noExercise, SetValues(reps: 5), at: now), .logSet(noSet, SetValues(reps: 5), at: now),
            .reopenSet(noExercise), .reopenSet(noSet),
            .updateSet(noExercise, SetValues(reps: 5)), .updateSet(noSet, SetValues(reps: 5)),
            .setSkipped(exerciseOrder: 99, true),
        ]
        for command in commands {
            #expect(expectSame(command, on: workout, .ignored) == before)
        }
    }
}
