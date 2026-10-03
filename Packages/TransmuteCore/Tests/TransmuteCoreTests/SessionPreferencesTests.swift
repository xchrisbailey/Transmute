import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// The workout preferences (#18) taking effect in a session.
@MainActor
struct SessionPreferencesTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// A profile with a bar and kilo plates, and a day of squats at 100 kg then planks.
    func fixture(rest: Double? = nil, plannedWarmUp: Bool = false) throws -> (profile: Profile, day: PlanDay) {
        let profile = Profile()
        profile.equipment = [.barbell, .rack, .bench]
        profile.unitSystem = .metric
        profile.plates = PlateInventory(.commercialGym, system: .metric)
        context.insert(profile)
        let plan = Plan(name: "Test", startDate: now)
        context.insert(plan)
        let day = PlanDay(week: 1, weekday: 1, focus: "Lower")
        plan.days?.append(day)
        let squat = PlannedExercise(exerciseID: "back-squat", order: 0)
        day.exercises?.append(squat)
        var order = 0
        if plannedWarmUp {
            let set = PlannedSet(order: order)
            (set.targetReps, set.targetLoadKg, set.isWarmUp) = (8, 50, true)
            squat.sets?.append(set)
            order += 1
        }
        for _ in 0..<3 {
            let set = PlannedSet(order: order)
            (set.targetReps, set.targetLoadKg, set.restSeconds) = (5, 100, rest)
            squat.sets?.append(set)
            order += 1
        }
        let plank = PlannedExercise(exerciseID: "plank", order: 1)
        day.exercises?.append(plank)
        let hold = PlannedSet(order: 0)
        hold.targetSeconds = 30
        plank.sets?.append(hold)
        try context.save()
        return (profile, day)
    }

    func squat(_ workout: Workout) throws -> LoggedExercise {
        try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
    }

    // MARK: Rest

    @Test func setsWithoutARestGetTheDefault() throws {
        let (profile, day) = try fixture()
        profile.preferences.workingRestSeconds = 120
        profile.preferences.warmUpRestSeconds = 30
        let sets = try squat(WorkoutSession.start(day, profile: profile, at: now, in: context)).orderedSets
        #expect(sets.filter(\.isWarmUp).allSatisfy { $0.restSeconds == 30 })
        #expect(sets.filter { !$0.isWarmUp }.allSatisfy { $0.restSeconds == 120 })
        #expect(sets.filter { !$0.isWarmUp }.count == 3)
    }

    @Test func aPlannedRestWins() throws {
        let (profile, day) = try fixture(rest: 150)
        profile.preferences.workingRestSeconds = 60
        let sets = try squat(WorkoutSession.start(day, profile: profile, at: now, in: context)).orderedSets
        #expect(sets.filter { !$0.isWarmUp }.allSatisfy { $0.restSeconds == 150 })
    }

    @Test func addedSetsAndExercisesUseTheDefault() throws {
        let (profile, day) = try fixture()
        profile.preferences.workingRestSeconds = 75
        try context.save()
        let workout = WorkoutSession.start(day, profile: profile, at: now, in: context)
        let press = try #require(ExerciseLibrary.bundled.exercise(id: "bench-press"))
        let added = WorkoutSession.add(press, to: workout)
        #expect(added.orderedSets.allSatisfy { $0.restSeconds == 75 })
        let empty = LoggedExercise(exerciseID: "bench-press", order: 9)
        workout.exercises?.append(empty)
        #expect(WorkoutSession.addSet(to: empty).restSeconds == 75)
    }

    @Test func restStartsByItselfUnlessTurnedOff() throws {
        let (profile, day) = try fixture(rest: 150)
        let workout = WorkoutSession.start(day, profile: profile, at: now, in: context)
        let first = try #require(WorkoutSession.currentSet(of: workout))
        #expect(WorkoutSession.complete(first, in: workout, at: now) == first.restSeconds)
        #expect(workout.restEndsAt != nil)
        #expect(SessionSnapshot(workout).autoStartsRest == true)

        WorkoutSession.startRest(nil, in: workout)
        profile.preferences.autoStartRest = false
        try context.save()
        let second = try #require(WorkoutSession.currentSet(of: workout))
        #expect(WorkoutSession.complete(second, in: workout, at: now.addingTimeInterval(60)) == nil)
        #expect(workout.restEndsAt == nil)
        #expect(SessionSnapshot(workout).autoStartsRest == false)
    }

    @Test func theWatchFollowsAutoStartToo() throws {
        let (profile, day) = try fixture(rest: 150)
        profile.preferences = WorkoutPreferences(autoStartRest: false, warmUpSets: false)
        try context.save()
        let workout = WorkoutSession.start(day, profile: profile, at: now, in: context)
        let snapshot = SessionSnapshot(workout)
        let ref = try #require(snapshot.current)
        let command = SessionCommand.logSet(ref, SetValues(weightKg: 100, reps: 5), at: now)
        // What the mirroring device shows straight away, and what the owner then does.
        #expect(snapshot.applying(command).restEndsAt == nil)
        #expect(SessionMirror.apply(command, to: workout, in: context) == .applied)
        #expect(workout.restEndsAt == nil)

        var older = snapshot
        older.autoStartsRest = nil
        #expect(older.applying(command).restEndsAt == now.addingTimeInterval(150))
    }

    @Test func restCanBeStartedByHand() throws {
        let (profile, day) = try fixture(rest: 150)
        profile.preferences = WorkoutPreferences(autoStartRest: false, warmUpSets: false)
        try context.save()
        let workout = WorkoutSession.start(day, profile: profile, at: now, in: context)
        #expect(WorkoutSession.restToStart(in: workout, at: now) == nil)
        let first = try #require(WorkoutSession.currentSet(of: workout))
        WorkoutSession.complete(first, in: workout, at: now)
        #expect(WorkoutSession.restToStart(in: workout, at: now) == 150)
        WorkoutSession.startRest(150, in: workout, at: now)
        #expect(WorkoutSession.restToStart(in: workout, at: now) == nil)
        // Nothing to rest for once every set is in.
        WorkoutSession.startRest(nil, in: workout)
        for set in workout.orderedExercises.flatMap(\.orderedSets) where !set.isCompleted {
            WorkoutSession.complete(set, in: workout, at: now.addingTimeInterval(300))
        }
        #expect(WorkoutSession.restToStart(in: workout, at: now.addingTimeInterval(600)) == nil)
    }

    // MARK: Warm-ups

    @Test func barbellLiftsGetARamp() throws {
        let (profile, day) = try fixture(rest: 150)
        let workout = WorkoutSession.start(day, profile: profile, at: now, in: context)
        let sets = try squat(workout).orderedSets
        let ramp = PlateCalculator(inventory: profile.plates).warmUps(to: 100)
        #expect(!ramp.isEmpty)
        #expect(sets.map(\.order) == Array(0..<sets.count))
        #expect(sets.prefix(ramp.count).allSatisfy { $0.isWarmUp })
        #expect(sets.prefix(ramp.count).map(\.weightKg) == ramp.map(\.loading.totalKg))
        #expect(sets.prefix(ramp.count).map(\.reps) == ramp.map(\.reps))
        #expect(sets.dropFirst(ramp.count).map(\.weightKg) == [100, 100, 100])
        #expect(sets.dropFirst(ramp.count).allSatisfy { !$0.isWarmUp && $0.restSeconds == 150 })
        // The plank isn't loaded on a bar.
        let plank = try #require(workout.orderedExercises.first { $0.exerciseID == "plank" })
        #expect(plank.orderedSets.count == 1)
        #expect(WorkoutSession.currentSet(of: workout)?.isWarmUp == true)
    }

    @Test func noRampWithoutABar() throws {
        let (profile, day) = try fixture()
        profile.equipment = [.dumbbell]
        let sets = try squat(WorkoutSession.start(day, profile: profile, at: now, in: context)).orderedSets
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { !$0.isWarmUp })
    }

    @Test func plannedWarmUpsAreKeptAsWritten() throws {
        let (profile, day) = try fixture(plannedWarmUp: true)
        let sets = try squat(WorkoutSession.start(day, profile: profile, at: now, in: context)).orderedSets
        #expect(sets.map(\.isWarmUp) == [true, false, false, false])
        #expect(sets.first?.weightKg == 50)
        #expect(sets.first?.restSeconds == 45)
    }

    @Test func turningWarmUpsOffLeavesThemAllOut() throws {
        for plannedWarmUp in [false, true] {
            let (profile, day) = try fixture(plannedWarmUp: plannedWarmUp)
            profile.preferences.warmUpSets = false
            let sets = try squat(WorkoutSession.start(day, profile: profile, at: now, in: context)).orderedSets
            #expect(sets.map(\.order) == [0, 1, 2])
            #expect(sets.allSatisfy { !$0.isWarmUp && $0.weightKg == 100 })
        }
    }
}
