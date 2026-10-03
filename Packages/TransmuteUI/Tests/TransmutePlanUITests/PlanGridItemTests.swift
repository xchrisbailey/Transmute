import Foundation
import SwiftData
import Testing
import TransmuteCore

@testable import TransmutePlanUI

@MainActor
struct PlanGridItemTests {
    let container: ModelContainer
    let plan: Plan

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        plan = SampleData.plan(startingOn: Date(timeIntervalSince1970: 1_790_380_800))
        container.mainContext.insert(plan)
        try container.mainContext.save()
    }

    func day(_ week: Int, _ weekday: Weekday) -> PlanDay? {
        PlanEditor.day(of: plan, week: week, weekday: weekday)
    }

    @Test func payloadSurvivesADrag() throws {
        let monday = try #require(day(1, 1))
        let item = PlanGridItem(day: monday, in: plan, exercise: monday.orderedExercises[2])
        let decoded = try JSONDecoder().decode(PlanGridItem.self, from: JSONEncoder().encode(item))
        #expect(decoded == item)
        #expect(decoded.exercise == 2)
        #expect(PlanGridItem(day: monday, in: plan).exercise == nil)
    }

    @Test func aDayDropsOnAnEmptyWeekdayOrSwaps() throws {
        let monday = try #require(day(1, 1))
        let wednesday = try #require(day(1, 3))
        #expect(PlanGridItem(day: monday, in: plan).drop(in: plan, week: 1, weekday: 2))
        #expect(monday.weekday == 2)
        #expect(PlanGridItem(day: monday, in: plan).drop(in: plan, week: 1, weekday: 3))
        #expect(monday.weekday == 3 && wednesday.weekday == 2)
    }

    @Test func aDayStaysInItsWeek() throws {
        let monday = try #require(day(1, 1))
        let item = PlanGridItem(day: monday, in: plan)
        #expect(!item.drop(in: plan, week: 2, weekday: 2))
        #expect(!item.drop(in: plan, week: 1, weekday: 1))
        #expect(!item.drop(in: Plan(name: "Another"), week: 1, weekday: 2))
        #expect(monday.weekday == 1 && !monday.isEdited)
    }

    @Test func anExerciseTakesThePlaceOfTheRowItLandsOn() throws {
        let monday = try #require(day(1, 1))
        let ids = monday.orderedExercises.map(\.exerciseID)
        // Dragged down onto the third row, then back up onto the first.
        var item = PlanGridItem(day: monday, in: plan, exercise: monday.orderedExercises[0])
        #expect(item.drop(in: plan, week: 1, weekday: 1, onto: monday.orderedExercises[2]))
        #expect(monday.orderedExercises.map(\.exerciseID) == [ids[1], ids[2], ids[0], ids[3], ids[4]])
        item = PlanGridItem(day: monday, in: plan, exercise: monday.orderedExercises[2])
        #expect(item.drop(in: plan, week: 1, weekday: 1, onto: monday.orderedExercises[0]))
        #expect(monday.orderedExercises.map(\.exerciseID) == ids)
        // Onto itself: nothing to do.
        item = PlanGridItem(day: monday, in: plan, exercise: monday.orderedExercises[1])
        #expect(!item.drop(in: plan, week: 1, weekday: 1, onto: monday.orderedExercises[1]))
    }

    @Test func anExerciseDropsOnAnotherDay() throws {
        let monday = try #require(day(1, 1))
        let friday = try #require(day(2, 5))
        let squat = monday.orderedExercises[1]
        let lunge = monday.orderedExercises[3]
        // On a row: before it. On the card: last.
        let onRow = PlanGridItem(day: monday, in: plan, exercise: squat)
        #expect(onRow.drop(in: plan, week: 2, weekday: 5, onto: friday.orderedExercises[0]))
        #expect(friday.orderedExercises.first === squat)
        #expect(PlanGridItem(day: monday, in: plan, exercise: lunge).drop(in: plan, week: 2, weekday: 5))
        #expect(friday.orderedExercises.last === lunge)
        #expect(friday.orderedExercises.map(\.order) == Array(0..<8))
        #expect(monday.orderedExercises.map(\.order) == Array(0..<3))
    }

    @Test func anExerciseNeedsASessionToLandOn() throws {
        let monday = try #require(day(1, 1))
        let item = PlanGridItem(day: monday, in: plan, exercise: monday.orderedExercises[0])
        #expect(!item.drop(in: plan, week: 1, weekday: 2))
        #expect(monday.orderedExercises.count == 5 && !monday.isEdited)
    }
}
