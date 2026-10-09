import Foundation
import SwiftData
import Testing
import TransmuteCore

@testable import TransmuteLogUI

/// Which logged sets wear the record marker on their row (#60): the ones with rows in
/// `LoggedSet.records`, the same rule History uses.
@MainActor
struct SetRecordMarkerTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    var book: RecordBook { RecordBook(context: context) }
    let day = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    @discardableResult
    func log(daysAgo: Int, weightKg: Double, reps: Int = 5) -> LoggedSet {
        let start = day.addingTimeInterval(Double(-daysAgo) * 86_400)
        let set = LoggedSet(order: 0, weightKg: weightKg, reps: reps)
        set.complete(at: start.addingTimeInterval(180))
        let exercise = LoggedExercise(exerciseID: "back-squat", order: 0)
        exercise.sets?.append(set)
        let workout = Workout(title: "Session", startedAt: start)
        workout.exercises?.append(exercise)
        context.insert(workout)
        return set
    }

    @Test func aRecordSetIsMarked() throws {
        log(daysAgo: 7, weightKg: 100)
        let better = log(daysAgo: 0, weightKg: 105)
        try book.recompute(exerciseID: "back-squat")
        try context.save()

        #expect(better.holdsRecord)
        #expect(!better.recordMarks.isEmpty)
    }

    @Test func aSetThatSetNoRecordIsNotMarked() throws {
        let baseline = log(daysAgo: 7, weightKg: 100)
        let lighter = log(daysAgo: 0, weightKg: 90)
        try book.recompute(exerciseID: "back-squat")
        try context.save()

        // The first ever set is a baseline, not a record.
        #expect(!baseline.holdsRecord)
        #expect(!lighter.holdsRecord)
        #expect(lighter.recordMarks.isEmpty)
    }

    @Test func aLaterBetterSetKeepsTheEarlierMarker() throws {
        log(daysAgo: 14, weightKg: 100)
        let middle = log(daysAgo: 7, weightKg: 105)
        let latest = log(daysAgo: 0, weightKg: 110)
        try book.recompute(exerciseID: "back-squat")
        try context.save()

        #expect(middle.holdsRecord)
        #expect(latest.holdsRecord)
    }

    @Test func warmUpsAreNumberedAmongWarmUpsOnly() {
        let exercise = LoggedExercise(exerciseID: "back-squat", order: 0)
        let first = LoggedSet(order: 0, weightKg: 40, reps: 8)
        let second = LoggedSet(order: 1, weightKg: 60, reps: 5)
        let working = LoggedSet(order: 2, weightKg: 100, reps: 5)
        first.isWarmUp = true
        second.isWarmUp = true
        exercise.sets = [second, working, first]

        #expect(first.warmUpNumber == 1)
        #expect(second.warmUpNumber == 2)
        #expect(working.warmUpNumber == nil)
    }

    @Test func editingASetSoItWasNeverARecordTakesTheMarkerAway() throws {
        log(daysAgo: 14, weightKg: 100)
        let middle = log(daysAgo: 7, weightKg: 105)
        let latest = log(daysAgo: 0, weightKg: 107.5)
        try book.recompute(exerciseID: "back-squat")
        try context.save()
        #expect(middle.holdsRecord && latest.holdsRecord)

        // Last week was really 110, so this week's 107.5 no longer beats anything.
        middle.weightKg = 110
        try book.recompute(exerciseID: "back-squat")
        try context.save()

        #expect(middle.holdsRecord)
        #expect(!latest.holdsRecord)
        #expect(latest.recordMarks.isEmpty)
    }
}
