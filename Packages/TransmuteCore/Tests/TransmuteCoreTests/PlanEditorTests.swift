import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct PlanEditorTests {
    let container: ModelContainer
    let plan: Plan
    var context: ModelContext { container.mainContext }
    let start = Date(timeIntervalSince1970: 1_790_380_800)  // Monday 2026-09-21, UTC.

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        plan = SampleData.plan(startingOn: start)
        container.mainContext.insert(plan)
        try container.mainContext.save()
    }

    var monday: PlanDay { plan.orderedDays.first { $0.week == 1 && $0.weekday == 1 }! }

    @Test func weekFollowsTheCalendarAndClamps() {
        #expect(PlanEditor.week(of: plan, on: start) == 1)
        #expect(PlanEditor.week(of: plan, on: start.addingTimeInterval(8 * 86_400)) == 2)
        #expect(PlanEditor.week(of: plan, on: start.addingTimeInterval(100 * 86_400)) == 4)
        #expect(PlanEditor.week(of: plan, on: start.addingTimeInterval(-86_400)) == 1)
    }

    @Test func movingOntoAnotherSessionSwapsThem() {
        let wednesday = plan.orderedDays.first { $0.week == 1 && $0.weekday == 3 }!
        let day = monday
        PlanEditor.move(day, to: 3)
        #expect(day.weekday == 3)
        #expect(wednesday.weekday == 1)
        #expect(day.isEdited && wednesday.isEdited)
        PlanEditor.move(day, to: 2)
        #expect(day.weekday == 2)
    }

    @Test func reorderAddAndRemove() throws {
        let day = monday
        let first = day.orderedExercises.map(\.exerciseID)
        PlanEditor.move(in: day, from: [0], to: 2)
        #expect(day.orderedExercises.map(\.exerciseID) == [first[1], first[0]] + first.dropFirst(2))
        let plank = try #require(ExerciseLibrary.bundled.exercise(id: "plank"))
        let added = PlanEditor.add(plank, to: day)
        #expect(day.orderedExercises.last === added)
        #expect(added.orderedSets.first?.targetSeconds == 30)
        PlanEditor.remove(day.orderedExercises[0], from: day, in: context)
        #expect(day.orderedExercises.map(\.order) == Array(0..<day.orderedExercises.count))
        #expect(day.isEdited)
    }

    @Test func swappingKeepsSetsWhenTrackingMatches() throws {
        let squat = try #require(monday.orderedExercises.first { $0.exerciseID == "back-squat" })
        let sets = squat.orderedSets.count
        let goblet = try #require(ExerciseLibrary.bundled.exercise(id: "goblet-squat"))
        PlanEditor.swap(squat, for: goblet)
        #expect(squat.exerciseID == "goblet-squat")
        #expect(squat.orderedSets.count == sets)
        #expect(squat.orderedSets.allSatisfy { $0.targetLoadKg == nil })

        let plank = try #require(ExerciseLibrary.bundled.exercise(id: "plank"))
        PlanEditor.swap(squat, for: plank)
        #expect(squat.orderedSets.count == sets)
        #expect(squat.orderedSets.allSatisfy { $0.targetSeconds == 30 && $0.targetReps == nil })
    }

    @Test func alternativesMatchPatternAndKit() {
        let options = PlanEditor.alternatives(to: "back-squat", equipment: [.dumbbell, .bench])
        #expect(!options.isEmpty)
        #expect(options.allSatisfy { $0.pattern == .squat && $0.isDoable(with: [.dumbbell, .bench]) })
        #expect(!options.contains { $0.id == "back-squat" })
    }

    @Test func setsCopyTheLastAndKeepOne() throws {
        let squat = try #require(monday.orderedExercises.first { $0.exerciseID == "back-squat" })
        let count = squat.orderedSets.count
        PlanEditor.addSet(to: squat)
        #expect(squat.orderedSets.count == count + 1)
        #expect(squat.orderedSets.last?.targetLoadKg == squat.orderedSets.first?.targetLoadKg)
        for _ in 0..<10 { PlanEditor.removeSet(from: squat, in: context) }
        #expect(squat.orderedSets.count == 1)
    }

    @Test func onlyOnePlanIsActive() throws {
        let other = Plan(name: "Older")
        context.insert(other)
        try PlanEditor.activate(other, in: context)
        #expect(other.isActive)
        #expect(!plan.isActive)
    }

    @Test func editsCanBeUndone() throws {
        context.undoManager = UndoManager()
        try context.save()
        let day = monday
        context.undoManager?.beginUndoGrouping()
        PlanEditor.move(day, to: 2)
        context.undoManager?.endUndoGrouping()
        context.processPendingChanges()
        #expect(day.weekday == 2)
        context.undoManager?.undo()
        #expect(day.weekday == 1)
    }
}
