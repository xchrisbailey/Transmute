import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct RecordBookTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    var book: RecordBook { RecordBook(context: context) }
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    /// A finished workout `daysAgo` before `day` with one exercise and these sets.
    @discardableResult
    func log(_ exerciseID: String, daysAgo: Int, _ sets: [LoggedSet]) -> Workout {
        let start = day.addingTimeInterval(Double(-daysAgo) * 86_400)
        let workout = Workout(title: "Session", startedAt: start)
        let exercise = LoggedExercise(exerciseID: exerciseID, order: 0)
        for (index, set) in sets.enumerated() {
            set.order = index
            set.complete(at: start.addingTimeInterval(Double(index + 1) * 180))
            exercise.sets?.append(set)
        }
        workout.exercises?.append(exercise)
        context.insert(workout)
        return workout
    }

    func records(_ exerciseID: String = "back-squat") throws -> [PersonalRecord] {
        try context.fetch(FetchDescriptor<PersonalRecord>()).filter { $0.exerciseID == exerciseID }
    }

    @Test func checkOffTurnsAHeavierSetGold() throws {
        log("back-squat", daysAgo: 7, [LoggedSet(order: 0, weightKg: 110, reps: 5)])
        try book.recompute(exerciseID: "back-squat")
        #expect(try records().isEmpty)

        let workout = log("back-squat", daysAgo: 0, [])
        let set = LoggedSet(order: 0, weightKg: 115, reps: 5)
        workout.orderedExercises[0].sets?.append(set)
        set.complete(at: day)
        let check = try book.check(set)
        #expect(check.gold.first?.kind == .repMax)
        #expect(check.gold.first?.reps == 5)
        #expect(check.gold.first?.value == 115)
        #expect(check.gold.allSatisfy { $0.set === set })
        #expect(check.needsConfirmation.isEmpty)
        try context.save()
        #expect(try records().count == check.gold.count)
    }

    @Test func theFirstEverSetIsABaseline() throws {
        let workout = log("back-squat", daysAgo: 0, [])
        let set = LoggedSet(order: 0, weightKg: 100, reps: 5)
        workout.orderedExercises[0].sets?.append(set)
        set.complete(at: day)
        #expect(try book.check(set).gold.isEmpty)
        #expect(try records().isEmpty)
    }

    @Test func warmUpsNeverTurnGold() throws {
        log("back-squat", daysAgo: 7, [LoggedSet(order: 0, weightKg: 100, reps: 5)])
        let warmUp = LoggedSet(order: 0, weightKg: 140, reps: 5)
        warmUp.isWarmUp = true
        log("back-squat", daysAgo: 0, [warmUp])
        #expect(try book.check(warmUp).gold.isEmpty)
    }

    @Test func sessionVolumeTurnsGoldOncePerSession() throws {
        log("back-squat", daysAgo: 7, (0..<3).map { _ in LoggedSet(order: 0, weightKg: 100, reps: 5) })
        let workout = log("back-squat", daysAgo: 0, [])
        var volumeToasts = 0
        for index in 0..<5 {
            let set = LoggedSet(order: index, weightKg: 100, reps: 5)
            workout.orderedExercises[0].sets?.append(set)
            set.complete(at: day.addingTimeInterval(Double(index) * 180))
            volumeToasts += try book.check(set).gold.filter { $0.kind == .sessionVolume }.count
        }
        #expect(volumeToasts == 1)
        let volume = try #require(try records().first { $0.kind == .sessionVolume })
        #expect(volume.value == 2_500)
        #expect(volume.set?.order == 3)
    }

    @Test func aSuspiciousSetWaitsForConfirmation() throws {
        log("back-squat", daysAgo: 7, [LoggedSet(order: 0, weightKg: 100, reps: 5)])
        let typo = LoggedSet(order: 0, weightKg: 1_000, reps: 5)
        log("back-squat", daysAgo: 0, [typo])
        let check = try book.check(typo)
        #expect(check.gold.isEmpty)
        #expect(check.needsConfirmation.first?.value == 1_000)
        #expect(try records().isEmpty)

        let confirmed = try book.confirm(typo)
        #expect(confirmed.needsConfirmation.isEmpty)
        #expect(confirmed.gold.first?.value == 1_000)
        #expect(typo.isRecordConfirmed)
    }

    @Test func recomputeIsIdempotent() throws {
        let (_, _) = SampleData.insert(into: context, now: day)
        try context.save()
        try book.recomputeAll()
        try context.save()
        let first = try context.fetch(FetchDescriptor<PersonalRecord>()).map(\.persistentModelID)
        #expect(!first.isEmpty)

        try book.recomputeAll()
        try context.save()
        let second = try context.fetch(FetchDescriptor<PersonalRecord>()).map(\.persistentModelID)
        #expect(Set(first) == Set(second))
    }

    @Test func sampleRecordsMatchItsProgression() throws {
        SampleData.insert(into: context, now: day)
        try book.recomputeAll()
        // Loads climb 2.5% a week, rounded to 0.5 kg: 90, 92 and 94.5 kg back squat for 4 × 5.
        let squat = try records().filter { $0.kind == .repMax && $0.reps == 5 }.map(\.value).sorted()
        #expect(squat == [92, 94.5])
        // Sprints and holds repeat the plan exactly, so they set baselines and never turn gold.
        #expect(try records("acceleration-sprint").isEmpty)
        #expect(try records("hip-90-90").isEmpty)
    }

    @Test func editingAPastSetRecomputes() throws {
        log("back-squat", daysAgo: 14, [LoggedSet(order: 0, weightKg: 100, reps: 5)])
        let middle = LoggedSet(order: 0, weightKg: 105, reps: 5)
        log("back-squat", daysAgo: 7, [middle])
        let latest = LoggedSet(order: 0, weightKg: 107.5, reps: 5)
        log("back-squat", daysAgo: 0, [latest])
        try book.recompute(exerciseID: "back-squat")
        #expect(try records().filter { $0.kind == .repMax && $0.reps == 5 }.map(\.value).sorted() == [105, 107.5])

        // Last week was really 110, so this week's 107.5 is no longer a record.
        middle.weightKg = 110
        try book.recompute(exerciseID: "back-squat")
        try context.save()
        let fiveRMs = try records().filter { $0.kind == .repMax && $0.reps == 5 }
        #expect(fiveRMs.map(\.value) == [110])
        #expect(fiveRMs.first?.set === middle)
        #expect(try records().allSatisfy { $0.set !== latest })
    }

    @Test func deletingASetOrWorkoutRecomputes() throws {
        log("back-squat", daysAgo: 14, [LoggedSet(order: 0, weightKg: 100, reps: 5)])
        let middle = LoggedSet(order: 0, weightKg: 105, reps: 5)
        let middleWorkout = log("back-squat", daysAgo: 7, [middle])
        let latest = LoggedSet(order: 0, weightKg: 107.5, reps: 5)
        log("back-squat", daysAgo: 0, [latest])
        try book.recompute(exerciseID: "back-squat")
        try context.save()

        // Without last week, this week's 107.5 beats 100 instead.
        context.delete(middleWorkout)
        try book.recompute(exerciseID: "back-squat")
        try context.save()
        let fiveRMs = try records().filter { $0.kind == .repMax && $0.reps == 5 }
        #expect(fiveRMs.map(\.value) == [107.5])
        #expect(try records().allSatisfy { $0.set != nil })

        // Deleting the only later set leaves nothing but the baseline.
        context.delete(latest)
        try book.recompute(exerciseID: "back-squat")
        try context.save()
        #expect(try records().isEmpty)
    }

    @Test func customExercisesUseTheirTracking() throws {
        let custom = CustomExercise(name: "Wall sit", category: .strength, pattern: .squat, tracking: .time)
        context.insert(custom)
        log(custom.exerciseID, daysAgo: 7, [LoggedSet(order: 0, seconds: 60)])
        let hold = LoggedSet(order: 0, seconds: 90)
        log(custom.exerciseID, daysAgo: 0, [hold])
        #expect(book.tracking(for: custom.exerciseID) == .time)
        let check = try book.check(hold)
        #expect(check.gold.map(\.kind) == [.longestTime])
    }

    @Test func boardShowsCurrentBestsAndGoldSince() throws {
        SampleData.insert(into: context, now: day)
        try book.recomputeAll()
        let all = try context.fetch(FetchDescriptor<PersonalRecord>())

        let squat = try #require(RecordBoard.bests(all)["back-squat"])
        #expect(squat.first?.kind == .estimatedOneRepMax)
        #expect(squat.first { $0.kind == .repMax && $0.reps == 5 }?.value == 94.5)
        #expect(Set(squat.map(\.mark.slot)).count == squat.count)

        let lastWeek = day.addingTimeInterval(-14 * 86_400)
        let gold = RecordBoard.gold(all, since: lastWeek)
        #expect(!gold.isEmpty)
        #expect(gold.allSatisfy { group in group.allSatisfy { $0.date >= lastWeek && $0.set === group[0].set } })
        let dates = gold.compactMap { $0.first?.date }
        #expect(dates == dates.sorted(by: >))
        // Week 3's first set of 94.5 kg leads with its 5RM; its estimate and lighter maxes follow.
        let squatGroup = try #require(
            gold.first { group in group.contains { $0.exerciseID == "back-squat" && $0.value == 94.5 } })
        #expect(squatGroup.first?.kind == .repMax)
        #expect(squatGroup.first?.reps == 5)
        #expect(squatGroup.contains { $0.kind == .estimatedOneRepMax })
    }

    /// Two years of three sessions a week, five sets each: about 1,500 sets of one lift.
    @Test func recomputeHandlesAFewThousandSets() throws {
        for session in 0..<300 {
            let load = 60 + Double(session) * 0.25
            log(
                "back-squat", daysAgo: 600 - session * 2,
                (0..<5).map { _ in LoggedSet(order: 0, weightKg: load, reps: 5) })
        }
        try context.save()
        let clock = ContinuousClock()
        let elapsed = try clock.measure {
            try book.recompute(exerciseID: "back-squat")
            try book.recompute(exerciseID: "back-squat")
        }
        #expect(elapsed < .seconds(5))
        #expect(try records().count(where: { $0.kind == .repMax && $0.reps == 5 }) == 299)
    }
}
