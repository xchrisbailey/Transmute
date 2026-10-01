import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct WorkoutSessionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let calendar = Calendar(identifier: .iso8601)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// The sample plan with three weeks logged, and this week's Monday session.
    func monday() throws -> (plan: Plan, day: PlanDay) {
        let (_, plan) = SampleData.insert(into: context, now: now)
        try context.save()
        let day = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        return (plan, day)
    }

    @Test func startPrefillsEverySetFromTheTargets() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)

        #expect(workout.title == "Lower and power")
        #expect(workout.planDay === day)
        #expect(workout.orderedExercises.map(\.exerciseID) == day.orderedExercises.map(\.exerciseID))
        let squat = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        let planned = try #require(day.orderedExercises.first { $0.exerciseID == "back-squat" })
        #expect(squat.orderedSets.count == planned.orderedSets.count)
        #expect(squat.orderedSets.map(\.weightKg) == planned.orderedSets.map(\.targetLoadKg))
        #expect(squat.orderedSets.allSatisfy { $0.reps == 5 && $0.restSeconds == 150 && !$0.isCompleted })

        let friday = try #require(day.plan?.orderedDays.first { $0.week == 4 && $0.weekday == 5 })
        let intervals = WorkoutSession.start(friday, at: now, in: context)
        let bike = try #require(intervals.orderedExercises.first { $0.exerciseID == "assault-bike-intervals" })
        #expect(bike.orderedSets.first?.rounds == 8)
        #expect(bike.orderedSets.first?.seconds == 20)
        #expect(bike.orderedSets.first?.intervalRestSeconds == 10)
    }

    @Test func openLoadsComeFromTheLastTimeTheExerciseWasDone() throws {
        let (_, day) = try monday()
        for set in day.orderedExercises.flatMap(\.orderedSets) {
            set.targetLoadKg = nil
        }
        let workout = WorkoutSession.start(day, at: now, in: context)
        let squat = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        // Week 3 squatted 90 × 1.05, rounded to the half kilogram.
        #expect(squat.orderedSets.first?.weightKg == 94.5)
        let jump = try #require(workout.orderedExercises.first { $0.exerciseID == "box-jump" })
        #expect(jump.orderedSets.first?.weightKg == nil)
    }

    @Test func theCurrentSetWalksThroughTheWorkout() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let first = try #require(WorkoutSession.currentSet(of: workout))
        #expect(first.exercise?.exerciseID == "box-jump")
        #expect(first.order == 0)

        WorkoutSession.complete(first, in: workout, at: now)
        #expect(WorkoutSession.currentSet(of: workout)?.order == 1)

        let jumps = try #require(first.exercise)
        WorkoutSession.setSkipped(jumps, true)
        #expect(WorkoutSession.currentSet(of: workout)?.exercise?.exerciseID == "back-squat")
    }

    @Test func checkingOffStartsThePlannedRest() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let set = try #require(WorkoutSession.currentSet(of: workout))

        let rest = WorkoutSession.complete(set, in: workout, at: now)
        #expect(rest == 60)
        #expect(set.isCompleted && set.completedAt == now)
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(15)) == 45)
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(61)) == nil)

        WorkoutSession.adjustRest(by: 30, in: workout, at: now.addingTimeInterval(15))
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(15)) == 75)
        #expect(workout.restSeconds == 90)
        WorkoutSession.adjustRest(by: -120, in: workout, at: now.addingTimeInterval(15))
        #expect(workout.restEndsAt == nil)
    }

    @Test func theLastSetStartsNoRest() throws {
        let workout = WorkoutSession.startAdHoc(title: "Arms", at: now, in: context)
        let curl = try #require(ExerciseLibrary.bundled.search(ExerciseQuery(text: "curl")).first)
        let exercise = WorkoutSession.add(curl, to: workout, sets: 1)
        let set = try #require(exercise.orderedSets.first)
        #expect(WorkoutSession.complete(set, in: workout, at: now) == nil)
        #expect(workout.restEndsAt == nil)
    }

    @Test func aKilledAppResumesTheSameSetAndRest() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let set = try #require(WorkoutSession.currentSet(of: workout))
        set.reps = 3
        WorkoutSession.complete(set, in: workout, at: now)

        // A fresh context reads only what was saved.
        let relaunched = ModelContext(container)
        let resumed = try #require(try WorkoutSession.current(in: relaunched))
        #expect(resumed.id == workout.id)
        #expect(WorkoutSession.currentSet(of: resumed)?.order == 1)
        #expect(resumed.orderedExercises.first?.orderedSets.first?.reps == 3)
        #expect(WorkoutSession.restRemaining(in: resumed, at: now.addingTimeInterval(20)) == 40)
    }

    @Test func substitutingKeepsLoggedSetsOnTheOriginal() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let squat = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        let front = try #require(ExerciseLibrary.bundled.exercise(id: "front-squat"))
        WorkoutSession.complete(squat.orderedSets[0], in: workout, at: now)

        let replacement = WorkoutSession.substitute(squat, with: front, in: workout)
        #expect(squat.orderedSets.count == 1)
        #expect(replacement.exerciseID == "front-squat")
        #expect(replacement.substitutedFromID == "back-squat")
        // Week 4 is a deload with three sets: one logged, two moved across.
        #expect(replacement.orderedSets.map(\.order) == [0, 1])
        #expect(replacement.orderedSets.allSatisfy { $0.weightKg == nil && $0.reps == 5 })
        #expect(workout.orderedExercises.map(\.exerciseID).prefix(3) == ["box-jump", "back-squat", "front-squat"])
        #expect(WorkoutSession.currentSet(of: workout)?.exercise?.exerciseID == "box-jump")
    }

    @Test func substitutingBeforeLoggingChangesInPlace() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let squat = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        let plank = try #require(ExerciseLibrary.bundled.exercise(id: "plank"))
        let count = workout.orderedExercises.count

        let replacement = WorkoutSession.substitute(squat, with: plank, in: workout)
        #expect(replacement === squat)
        #expect(workout.orderedExercises.count == count)
        #expect(squat.orderedSets.allSatisfy { $0.reps == nil && $0.seconds == 30 && $0.restSeconds == 150 })
    }

    @Test func addingAndRemovingSets() throws {
        let workout = WorkoutSession.startAdHoc(title: "Extra", at: now, in: context)
        let curl = try #require(ExerciseLibrary.bundled.exercise(id: "dumbbell-curl"))
        let exercise = WorkoutSession.add(curl, to: workout, sets: 2)
        exercise.orderedSets[1].weightKg = 30
        let third = WorkoutSession.addSet(to: exercise)
        #expect(third.order == 2 && third.weightKg == 30 && third.reps == 10)

        WorkoutSession.remove(exercise.orderedSets[0], from: exercise)
        #expect(exercise.orderedSets.map(\.order) == [0, 1])
    }

    @Test func finishingDropsWhatWasntLogged() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        let squat = try #require(workout.orderedExercises.first { $0.exerciseID == "back-squat" })
        for (index, set) in squat.orderedSets.enumerated() {
            WorkoutSession.complete(set, in: workout, at: now.addingTimeInterval(Double(index) * 180))
        }
        let end = now.addingTimeInterval(1_800)
        let summary = WorkoutSession.finish(workout, at: end)

        #expect(workout.endedAt == end)
        #expect(workout.restEndsAt == nil)
        #expect(workout.orderedExercises.map(\.exerciseID) == ["back-squat"])
        #expect(summary.sets == squat.orderedSets.count)
        #expect(summary.exercises == 1)
        #expect(summary.volumeKg == squat.orderedSets.reduce(0) { $0 + $1.weightKg! * 5 })
        #expect(summary.duration == 1_800)
        #expect(try WorkoutSession.current(in: context) == nil)
    }

    @Test func discardingDeletesEverything() throws {
        let (_, day) = try monday()
        let workout = WorkoutSession.start(day, at: now, in: context)
        WorkoutSession.discard(workout, in: context)
        #expect(try WorkoutSession.current(in: context) == nil)
        #expect(day.workouts?.contains { $0.endedAt == nil } != true)
    }

    // MARK: Today

    @Test func todayFindsThePlannedSession() throws {
        let (plan, _) = try monday()
        let thisMonday = calendar.dateInterval(of: .weekOfYear, for: now)!.start.addingTimeInterval(9 * 3_600)
        let today = TodayPlan(plan: plan, on: thisMonday)
        #expect(today.week == 4)
        #expect(today.day?.focus == "Lower and power")
        #expect(today.day?.week == 4)
        #expect(!today.isDone)
        #expect(today.next?.weekday == 3)

        let tuesday = TodayPlan(plan: plan, on: thisMonday.addingTimeInterval(86_400))
        #expect(tuesday.day == nil)
        #expect(tuesday.next?.weekday == 3)

        let lastMonday = TodayPlan(plan: plan, on: thisMonday.addingTimeInterval(-7 * 86_400))
        #expect(lastMonday.isDone)
    }
}
