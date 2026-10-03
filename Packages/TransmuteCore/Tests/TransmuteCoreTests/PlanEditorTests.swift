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

    @Test func findsTheDayOnAWeekday() {
        #expect(PlanEditor.day(of: plan, week: 1, weekday: 1) === monday)
        #expect(PlanEditor.day(of: plan, week: 1, weekday: 2) == nil)
        #expect(PlanEditor.day(of: plan, week: 2, weekday: 1)?.week == 2)
    }

    @Test func movingADayOnlyTouchesItsOwnWeek() {
        let nextMonday = plan.orderedDays.first { $0.week == 2 && $0.weekday == 1 }!
        PlanEditor.move(monday, to: 7)
        #expect(PlanEditor.day(of: plan, week: 1, weekday: 7)?.focus == "Lower and power")
        #expect(PlanEditor.day(of: plan, week: 1, weekday: 1) == nil)
        #expect(nextMonday.weekday == 1 && !nextMonday.isEdited)
        #expect(plan.orderedDays.filter { $0.week == 1 }.count == 3)
    }

    @Test func movingAnExerciseWithinItsDay() {
        let day = monday
        let ids = day.orderedExercises.map(\.exerciseID)
        // Down: the first exercise lands where the third was.
        PlanEditor.move(day.orderedExercises[0], to: day, at: 2)
        #expect(day.orderedExercises.map(\.exerciseID) == [ids[1], ids[2], ids[0], ids[3], ids[4]])
        // Up, and past the end clamps to last.
        PlanEditor.move(day.orderedExercises[2], to: day, at: 0)
        #expect(day.orderedExercises.map(\.exerciseID) == ids)
        PlanEditor.move(day.orderedExercises[1], to: day, at: 99)
        #expect(day.orderedExercises.map(\.exerciseID) == [ids[0], ids[2], ids[3], ids[4], ids[1]])
        #expect(day.orderedExercises.map(\.order) == Array(0..<5))
        #expect(day.exercises?.count == 5)
        #expect(day.isEdited)
    }

    @Test func droppingAnExerciseWhereItAlreadyIsChangesNothing() {
        let day = monday
        PlanEditor.move(day.orderedExercises[1], to: day, at: 1)
        PlanEditor.move(day.orderedExercises[4], to: day)
        #expect(!day.isEdited)
    }

    @Test func movingAnExerciseToAnotherDay() throws {
        let day = monday
        let wednesday = try #require(PlanEditor.day(of: plan, week: 1, weekday: 3))
        let squat = try #require(day.orderedExercises.first { $0.exerciseID == "back-squat" })
        let sets = squat.orderedSets.count
        let before = wednesday.orderedExercises.map(\.exerciseID)

        PlanEditor.move(squat, to: wednesday, at: 1)
        #expect(squat.day === wednesday)
        #expect(wednesday.orderedExercises.map(\.exerciseID) == [before[0], "back-squat"] + before.dropFirst())
        #expect(wednesday.orderedExercises.map(\.order) == Array(0..<6))
        #expect(!day.orderedExercises.contains { $0 === squat })
        #expect(day.orderedExercises.map(\.order) == Array(0..<4))
        #expect(squat.orderedSets.count == sets)
        #expect(day.isEdited && wednesday.isEdited)

        // Without an index it goes last, and it leaves its superset partner behind.
        let press = try #require(wednesday.orderedExercises.first { $0.supersetGroup == 1 })
        PlanEditor.move(press, to: day)
        #expect(day.orderedExercises.last === press)
        #expect(press.supersetGroup == nil)
        #expect(day.orderedExercises.map(\.order) == Array(0..<5))
        #expect(wednesday.orderedExercises.map(\.order) == Array(0..<5))
    }

    @Test func movingAnExerciseAcrossDaysCanBeUndone() throws {
        context.undoManager = UndoManager()
        try context.save()
        let day = monday
        let wednesday = try #require(PlanEditor.day(of: plan, week: 1, weekday: 3))
        let ids = day.orderedExercises.map(\.exerciseID)
        context.undoManager?.beginUndoGrouping()
        PlanEditor.move(day.orderedExercises[1], to: wednesday, at: 0)
        context.undoManager?.endUndoGrouping()
        context.processPendingChanges()
        #expect(wednesday.orderedExercises.first?.exerciseID == ids[1])
        context.undoManager?.undo()
        #expect(day.orderedExercises.map(\.exerciseID) == ids)
        #expect(wednesday.orderedExercises.count == 5)
        #expect(!day.isEdited && !wednesday.isEdited)
    }

    @Test func setCountGrowsAndShrinksButKeepsOne() throws {
        let squat = try #require(monday.orderedExercises.first { $0.exerciseID == "back-squat" })
        let load = squat.orderedSets.first?.targetLoadKg
        PlanEditor.setSetCount(of: squat, to: 6, in: context)
        #expect(squat.orderedSets.count == 6)
        #expect(squat.orderedSets.map(\.order) == Array(0..<6))
        #expect(squat.orderedSets.allSatisfy { $0.targetLoadKg == load })
        PlanEditor.setSetCount(of: squat, to: 2, in: context)
        #expect(squat.orderedSets.count == 2)
        PlanEditor.setSetCount(of: squat, to: 0, in: context)
        #expect(squat.orderedSets.count == 1)
        #expect(monday.isEdited)
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
