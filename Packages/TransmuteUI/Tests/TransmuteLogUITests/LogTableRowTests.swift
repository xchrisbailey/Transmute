import Foundation
import SwiftData
import Testing
import TransmuteCore

@testable import TransmuteLogUI

@MainActor
struct LogTableRowTests {
    @Test func rowsCarryTheFiguresTheColumnsSortBy() throws {
        let container = try SampleData.previewContainer()
        let context = container.mainContext
        let workouts = WorkoutLog.workouts(try context.fetch(FetchDescriptor<Workout>()), matching: .init())
        let first = try #require(workouts.first)
        let set = try #require(first.orderedExercises.first?.orderedSets.first)
        let record = PersonalRecord(exerciseID: "back-squat", kind: .estimatedOneRepMax, value: 120, set: set)
        context.insert(record)

        let rows = LogTableRow.rows(workouts, records: [record])
        #expect(rows.count == workouts.count)
        #expect(rows.first?.records == 1)
        #expect(rows.dropFirst().allSatisfy { $0.records == 0 })
        #expect(rows.first?.sets == WorkoutSummary(first).sets)
        #expect(rows.first?.volumeKg == first.volumeKg)

        let byVolume = rows.sorted(using: [KeyPathComparator(\LogTableRow.volumeKg, order: .reverse)])
        #expect(byVolume.map(\.volumeKg) == rows.map(\.volumeKg).sorted(by: >))
        let byDate = rows.sorted(using: [KeyPathComparator(\LogTableRow.date)])
        #expect(byDate.first?.date == workouts.last?.startedAt)
    }
}
