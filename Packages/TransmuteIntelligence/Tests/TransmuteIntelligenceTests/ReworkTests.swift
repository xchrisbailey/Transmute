import Foundation
import SwiftData
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

@MainActor
struct ReworkTests {
    let library = ExerciseLibrary.bundled

    @Test func notesAreReadByRules() {
        let note = ReworkNote("No barbell today, only 30 minutes, and my knee's sore")
        #expect(note.withoutEquipment == [.barbell])
        #expect(note.minutes == 30)
        #expect(note.areas == [.knee])
        let brief = note.applied(to: .tennisPlayer)
        #expect(!brief.equipment.contains(.barbell))
        #expect(brief.schedule.sessionMinutes == 30)
        #expect(brief.limitationAreas.contains(.knee))
        #expect(ReworkNote("feeling great").withoutEquipment.isEmpty)
    }

    @Test func dayKindsAreInferredFromExercises() {
        func kind(_ ids: String...) -> DayKind { DayKind.infer(from: ids.compactMap(library.exercise(id:))) }
        #expect(kind("back-squat", "romanian-deadlift", "pallof-press") == .lowerStrength)
        #expect(kind("bench-press", "pull-up") == .upperStrength)
        #expect(kind("back-squat", "bench-press") == .fullBody)
        #expect(kind("split-step-reaction", "acceleration-sprint", "box-jump") == .powerSpeed)
        #expect(kind("hip-90-90") == .mobility)
    }

    @Test func reworkHonoursTheNote() async throws {
        let brewer = PlanBrewer(service: PreviewIntelligenceService())
        let target = ReworkTarget(
            focus: "Lower and power", weekday: 1, currentIDs: ["box-jump", "back-squat", "romanian-deadlift"],
            phase: PlanPhase(name: "Build", focus: "Base", firstWeek: 1, lastWeek: 4), week: 2)
        let day = try await brewer.rework(
            target, note: "no barbell today, knee is sore", brief: .tennisPlayer, units: .metric)
        #expect(!day.exercises.isEmpty)
        for exercise in day.exercises {
            let found = try #require(library.exercise(id: exercise.exerciseID))
            #expect(
                !found.allEquipment.contains(.barbell)
                    || found.isDoable(with: TrainingBrief.tennisPlayer.equipment.subtracting([.barbell])), "\(found.id)"
            )
            #expect(!LimitationRules.excludes(found, areas: [.knee]), "\(found.id)")
        }
    }

    @Test func replacingADayMarksItEdited() throws {
        let container = try TransmuteStore.makeContainer(.inMemory)
        let plan = SampleData.plan(startingOn: .now)
        container.mainContext.insert(plan)
        let day = try #require(plan.orderedDays.first)
        let template = TemplateDay(
            weekday: day.weekday, focus: day.focus, why: "Fresh legs.", kind: .fullBody,
            exercises: [BrewedExercise(exerciseID: "goblet-squat", sets: [BrewedSet(reps: 10), BrewedSet(reps: 10)])])
        template.replaceExercises(of: day, in: container.mainContext)
        try container.mainContext.save()
        #expect(day.orderedExercises.map(\.exerciseID) == ["goblet-squat"])
        #expect(day.orderedExercises.first?.orderedSets.count == 2)
        #expect(day.notes == "Fresh legs.")
        #expect(day.isEdited)
        #expect(
            try container.mainContext.fetchCount(FetchDescriptor<PlannedExercise>())
                == plan.orderedDays.reduce(0) { $0 + $1.orderedExercises.count })
    }

    @Test func rebrewKeepsLoggedAndEditedDays() async throws {
        let container = try TransmuteStore.makeContainer(.inMemory)
        let context = container.mainContext
        let (_, plan) = SampleData.insert(into: context)  // Weeks 1–3 logged.
        let edited = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        edited.isEdited = true
        edited.focus = "Mine"
        try context.save()

        var brief = TrainingBrief.tennisPlayer
        brief.schedule.weeks = plan.weekCount
        brief.schedule.daysPerWeek = 3
        brief.schedule.preferredWeekdays = [1, 3, 5]
        var brewed: BrewedPlan?
        for try await progress in PlanBrewer(service: PreviewIntelligenceService()).brew(brief, units: .metric) {
            if case .finished(let plan) = progress { brewed = plan }
        }
        try #require(brewed).replaceWeeks(of: plan, from: 3, in: context)
        let days = plan.orderedDays
        #expect(days.filter { $0.week == 3 }.allSatisfy { !($0.workouts ?? []).isEmpty }, "Logged days stay")
        #expect(days.contains { $0.week == 4 && $0.focus == "Mine" }, "Edited days stay")
        #expect(days.filter { $0.week == 4 }.count == 3)

        try #require(brewed).replaceWeeks(of: plan, from: 4, keepEdits: false, in: context)
        #expect(!plan.orderedDays.contains { $0.focus == "Mine" })
    }
}
