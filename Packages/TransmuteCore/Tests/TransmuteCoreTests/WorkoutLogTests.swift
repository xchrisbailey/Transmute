import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct WorkoutLogTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try TransmuteStore.makeTestContainer()
    }

    func sample() throws -> [Workout] {
        SampleData.insert(into: context, now: now)
        try context.save()
        return try context.fetch(FetchDescriptor<Workout>())
    }

    @Test func groupsFinishedWorkoutsByWeekNewestFirst() throws {
        let all = try sample()
        let running = WorkoutSession.startAdHoc(title: "Still going", at: now, in: context)
        let weeks = WorkoutLog.weeks(WorkoutLog.workouts(all + [running], matching: .init()))

        #expect(weeks.count == 3)
        #expect(weeks.map { $0.workouts.count } == [3, 3, 3])
        #expect(weeks[0].start > weeks[1].start)
        #expect(
            weeks[0].workouts.map(\.title) == [
                "Speed, agility and conditioning", "Upper and rotation", "Lower and power",
            ])
        #expect(!weeks.flatMap(\.workouts).contains { $0 === running })
    }

    @Test func filtersByTextExercisePlanAndDates() throws {
        let all = try sample()
        let byName = WorkoutLog.workouts(all, matching: .init(text: "bench"))
        #expect(byName.count == 3 && byName.allSatisfy { $0.title == "Upper and rotation" })

        let byTitle = WorkoutLog.workouts(all, matching: .init(text: "lower"))
        #expect(byTitle.count == 3)

        let byExercise = WorkoutLog.workouts(all, matching: .init(exerciseID: "assault-bike-intervals"))
        #expect(byExercise.count == 3)

        let first = try #require(all.min { $0.startedAt < $1.startedAt })
        let dates = DateInterval(start: first.startedAt, duration: 3 * 86_400)
        #expect(WorkoutLog.workouts(all, matching: .init(dates: dates)).count == 2)

        #expect(WorkoutLog.workouts(all, matching: .init(planID: UUID())).isEmpty)
        let planID = try #require(first.planDay?.plan?.id)
        #expect(WorkoutLog.workouts(all, matching: .init(planID: planID)).count == 9)
    }

    @Test func editingASetRebuildsRecords() throws {
        let all = try sample()
        let book = RecordBook(context: context)
        _ = try book.recompute(exerciseID: "back-squat")
        let latest = try #require(all.filter { $0.title == "Lower and power" }.max { $0.startedAt < $1.startedAt })
        let squat = try #require(latest.orderedExercises.first { $0.exerciseID == "back-squat" })
        let set = try #require(squat.orderedSets.first)

        set.weightKg = 120
        try WorkoutLog.edited(set, in: context)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>()).filter { $0.exerciseID == "back-squat" }
        #expect(records.contains { $0.set === set && $0.kind == .repMax && $0.value == 120 })

        set.weightKg = 60
        try WorkoutLog.edited(set, in: context)
        let after = try context.fetch(FetchDescriptor<PersonalRecord>()).filter { $0.exerciseID == "back-squat" }
        #expect(!after.contains { $0.value == 120 })
    }

    @Test func deletingASetRenumbersAndDropsEmptyExercises() throws {
        let workout = WorkoutSession.startAdHoc(title: "Curls", at: now, in: context)
        let curl = try #require(ExerciseLibrary.bundled.exercise(id: "dumbbell-curl"))
        let exercise = WorkoutSession.add(curl, to: workout, sets: 2)
        for set in exercise.orderedSets {
            WorkoutSession.complete(set, in: workout, at: now)
        }
        WorkoutSession.finish(workout, at: now.addingTimeInterval(600))

        try WorkoutLog.delete(exercise.orderedSets[0], in: context)
        #expect(exercise.orderedSets.map(\.order) == [0])
        try WorkoutLog.delete(exercise.orderedSets[0], in: context)
        #expect(workout.orderedExercises.isEmpty)
    }

    @Test func deletingAWorkoutReturnsItsHealthWorkoutAndRebuildsRecords() throws {
        let all = try sample()
        _ = try RecordBook(context: context).recomputeAll()
        let latest = try #require(all.filter { $0.title == "Lower and power" }.max { $0.startedAt < $1.startedAt })
        let healthID = UUID()
        latest.healthKitWorkoutID = healthID
        let latestSets = latest.orderedExercises.flatMap(\.orderedSets)

        #expect(try WorkoutLog.delete(latest, in: context) == healthID)
        #expect(try context.fetch(FetchDescriptor<Workout>()).count == 8)
        let records = try context.fetch(FetchDescriptor<PersonalRecord>())
        #expect(!records.contains { record in latestSets.contains { $0 === record.set } })
    }

    @Test func exerciseHistoryTracksTheEstimatedMax() throws {
        let all = try sample()
        let history = WorkoutLog.history(of: "back-squat", in: all)
        #expect(history.count == 3)
        #expect(history[0].workout.startedAt > history[1].workout.startedAt)
        let best = try #require(history[0].estimatedOneRepMaxKg)
        #expect(abs(best - 94.5 * (1 + 5.0 / 30)) < 1e-9)
    }

    @Test func exerciseHistoryComesFromTheWorkoutsItIsGivenAndSkipsOneInProgress() throws {
        let all = try sample()
        let running = WorkoutSession.startAdHoc(title: "Still going", at: now, in: context)
        let squat = LoggedExercise(exerciseID: "back-squat", order: 0)
        squat.workout = running
        let set = LoggedSet(order: 0, weightKg: 200, reps: 5)
        set.complete(at: now)
        set.exercise = squat
        context.insert(squat)
        context.insert(set)

        #expect(WorkoutLog.history(of: "back-squat", in: all + [running]).count == 3)
        #expect(WorkoutLog.history(of: "back-squat", in: []).isEmpty)
        #expect(WorkoutLog.history(of: "back-squat", in: all.filter { $0.title == "Upper and rotation" }).isEmpty)
    }

    @Test func historyMergesARepeatedExerciseIntoOneEntry() throws {
        let workout = Workout(title: "Squat twice", startedAt: now)
        workout.endedAt = now.addingTimeInterval(3_600)
        let blocks: [(id: String, weights: [Double])] = [
            ("back-squat", [100, 100]), ("bench-press", [60]), ("back-squat", [80]),
        ]
        workout.exercises = blocks.enumerated().map { order, block in
            let exercise = LoggedExercise(exerciseID: block.id, order: order)
            exercise.sets = block.weights.enumerated().map { index, kg in
                let set = LoggedSet(order: index, weightKg: kg, reps: 5)
                set.complete(at: now)
                return set
            }
            return exercise
        }
        context.insert(workout)
        try context.save()

        let history = WorkoutLog.history(of: "back-squat", in: [workout])

        #expect(history.count == 1)
        #expect(history.first?.sets.map(\.weightKg) == [100, 100, 80])
    }
}
