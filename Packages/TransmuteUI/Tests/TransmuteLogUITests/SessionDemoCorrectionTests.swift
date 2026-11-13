import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteTestSupport

@testable import TransmuteLogUI

/// A shipped correction replaces bundled content only. Saved plans and logs keep pointing at the same
/// stable exercise ID, so the only thing an app update can change is the guidance a person sees.
@MainActor
struct SessionDemoCorrectionTests {
    private func content(video: String?) throws -> ExerciseLibrary {
        let pushUp = try #require(ExerciseLibrary.bundled.exercise(id: "push-up"))
        let demos = video.map { [synthetic("push-up", [.bodyweight], video: $0)] } ?? []
        return ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: demos)
    }

    private struct Saved: Equatable {
        let planned: [String]
        let plannedSets: [Int]
        let logged: [String]
        let setIDs: [PersistentIdentifier]
        let reps: [Int?]
    }

    private func fingerprint(of day: PlanDay, _ workout: Workout) -> Saved {
        let exercises = workout.orderedExercises
        return Saved(
            planned: day.orderedExercises.map(\.exerciseID),
            plannedSets: day.orderedExercises.map { $0.orderedSets.count },
            logged: exercises.map(\.exerciseID),
            setIDs: exercises.flatMap { $0.orderedSets.map(\.id) },
            reps: exercises.flatMap { $0.orderedSets.map(\.reps) })
    }

    /// A saved plan day of three push-up sets, started as a workout with its first set logged.
    private func savedPlanAndLog(at now: Date, in context: ModelContext) throws -> Workout {
        let plan = Plan(name: "Beginner")
        let day = PlanDay(week: 1, weekday: 2, focus: "Upper")
        let planned = PlannedExercise(exerciseID: "push-up", order: 0)
        for order in 0..<3 {
            let target = PlannedSet(order: order)
            target.targetReps = 8
            planned.sets?.append(target)
        }
        day.exercises?.append(planned)
        plan.days?.append(day)
        context.insert(plan)
        let workout = WorkoutSession.start(day, at: now, in: context)
        let exercise = try #require(workout.orderedExercises.first)
        WorkoutSession.complete(exercise.orderedSets[0], in: workout, at: now)
        try context.save()
        return workout
    }

    @Test func replacingThenRemovingAnAssociationChangesGuidanceButNotSavedWork() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let workout = try savedPlanAndLog(at: now, in: context)
        let day = try #require(workout.planDay)
        let exercise = try #require(workout.orderedExercises.first)
        let before = fingerprint(of: day, workout)
        let planID = try #require(day.plan?.id)

        // Installed content, then an update that replaces the video, then one that removes it.
        let installed = try content(video: "TESTONLY001")
        let replaced = try content(video: "TESTONLY002")
        let removed = try content(video: nil)

        func view(_ library: ExerciseLibrary) -> (SessionDemo, DemoPlayerSpy) {
            let player = DemoPlayerSpy()
            return (SessionDemo(workout: workout, library: library, player: player, appVersion: "0.3.1"), player)
        }

        let (first, firstPlayer) = view(installed)
        #expect(first.open(exercise) && first.viewed?.videoID == "TESTONLY001")
        #expect(firstPlayer.commands == ["load:TESTONLY001"])
        first.dismiss()

        let (second, secondPlayer) = view(replaced)
        #expect(second.open(exercise) && second.viewed?.videoID == "TESTONLY002")
        #expect(secondPlayer.commands == ["load:TESTONLY002"], "The replaced video is never loaded again")
        second.beginReport()
        #expect(second.report?.body.contains("watch?v=TESTONLY002") == true)
        second.dismiss()

        let (third, thirdPlayer) = view(removed)
        #expect(SessionDemo.guidance(for: "push-up", library: removed) == .cues)
        #expect(third.open(exercise))
        #expect(third.phase == .noVideo && third.viewed == nil && third.association == nil)
        #expect(third.cues == ExerciseLibrary.bundled.exercise(id: "push-up")?.cues && !third.cues.isEmpty)
        third.play()
        third.retry()
        third.beginReport()
        #expect(third.report == nil && thirdPlayer.commands.isEmpty)
        third.dismiss()

        // Nothing saved moved: same IDs, same plan, same logged set, in this context and a fresh one.
        #expect(!context.hasChanges)
        #expect(fingerprint(of: day, workout) == before)
        let fresh = ModelContext(container)
        let restoredPlan = try #require(try fresh.fetch(FetchDescriptor<Plan>()).first { $0.id == planID })
        let restoredDay = try #require(restoredPlan.orderedDays.first)
        let restoredWorkout = try #require(try WorkoutSession.current(in: fresh))
        #expect(fingerprint(of: restoredDay, restoredWorkout) == before)
        #expect(restoredWorkout.orderedExercises[0].orderedSets[0].isCompleted)
        #expect(restoredWorkout.orderedExercises[0].substitutedFromID == nil)
    }
}
