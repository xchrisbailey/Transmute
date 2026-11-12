import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteTestSupport

@testable import TransmuteLogUI

private struct RunningWorkout {
    let workout: Workout
    let exercise: LoggedExercise
    let first: LoggedSet
    let current: LoggedSet
}

@MainActor
struct SessionDemoEquipmentTests {
    @Test func unmappedLibraryExercisesKeepTheirCuesWithoutAPlayer() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let library = ExerciseLibrary.bundled
        let workout = WorkoutSession.startAdHoc(title: "Unsupported", in: context)
        let squat = try #require(library.exercise(id: "back-squat"))
        let exercise = WorkoutSession.add(squat, to: workout)
        #expect(SessionDemo.guidance(for: "back-squat", library: library) == .cues)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: library, player: player)
        #expect(demo.open(exercise))
        #expect(demo.cues == squat.cues && !demo.cues.isEmpty)
        #expect(demo.choices.isEmpty && demo.viewed == nil && demo.phase == .noVideo)
        demo.play()
        demo.retry()
        demo.dismiss()
        #expect(player.commands.isEmpty)
        #expect(!demo.isPresented)
    }

    @Test func guidanceIsOfferedOnlyWhereThereIsSomethingReal() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let pushUp = try #require(ExerciseLibrary.bundled.exercise(id: "push-up"))
        let fixture = synthetic("push-up", [.bodyweight], video: "TESTONLY001")
        let custom = CustomExercise(name: "Sled drag", category: .strength, pattern: .carry, tracking: .weightReps)
        custom.cues = ["Lean into the harness.", "   "]
        let bare = CustomExercise(name: "Bare", category: .strength, pattern: .carry, tracking: .weightReps)
        var silent = pushUp
        silent.id = "silent-push-up"
        silent.cues = []
        let library = ExerciseLibrary(catalogVersion: 1, exercises: [pushUp, silent], demos: [fixture])
            .adding([LibraryExercise(custom), LibraryExercise(bare)])
        #expect(SessionDemo.guidance(for: "push-up", library: library) == .demo)
        #expect(SessionDemo.guidance(for: custom.exerciseID, library: library) == .cues)
        #expect(SessionDemo.guidance(for: bare.exerciseID, library: library) == nil)
        #expect(SessionDemo.guidance(for: "silent-push-up", library: library) == nil)
        #expect(SessionDemo.guidance(for: "no-such-exercise", library: library) == nil)

        let workout = WorkoutSession.startAdHoc(title: "Custom", in: context)
        let drag = WorkoutSession.add(LibraryExercise(custom), to: workout)
        let empty = WorkoutSession.add(LibraryExercise(bare), to: workout)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: library, player: player)
        #expect(!demo.open(empty), "No supplied cues, no guessed guidance")
        #expect(demo.open(drag))
        #expect(demo.cues == ["Lean into the harness."])
        #expect(demo.viewed == nil && demo.phase == .noVideo)
        #expect(player.commands.isEmpty, "A custom name never earns a video")
        demo.dismiss()

        // Removing the last demo association leaves the same exercise's cues reachable.
        let stripped = ExerciseLibrary(catalogVersion: 1, exercises: [pushUp])
        let logged = WorkoutSession.add(pushUp, to: workout)
        #expect(SessionDemo.guidance(for: "push-up", library: stripped) == .cues)
        let later = SessionDemo(workout: workout, library: stripped, player: player)
        #expect(later.open(logged) && later.cues == pushUp.cues && later.phase == .noVideo)
        #expect(player.commands.isEmpty)
    }

    /// One logged set and an unlogged current set holding entered values, mid-rest.
    private func runningWorkout(
        of library: LibraryExercise, at now: Date, in context: ModelContext
    ) throws -> RunningWorkout {
        let workout = WorkoutSession.startAdHoc(title: "Equipment", at: now, in: context)
        let exercise = WorkoutSession.add(library, to: workout, sets: 3)
        let first = exercise.orderedSets[0]
        first.reps = 8
        first.restSeconds = 60
        WorkoutSession.complete(first, in: workout, at: now)
        let current = try #require(WorkoutSession.currentSet(of: workout))
        current.reps = 7
        current.weightKg = 12.5
        try context.save()
        return RunningWorkout(workout: workout, exercise: exercise, first: first, current: current)
    }

    @Test func viewingAnotherEquipmentStopsThePreviousVideoAndNeverTouchesTheWorkout() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let goblet = try #require(ExerciseLibrary.bundled.exercise(id: "goblet-squat"))
        let library = ExerciseLibrary(
            catalogVersion: 1, exercises: [goblet],
            demos: [synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001")])
        let running = try runningWorkout(of: goblet, at: now, in: context)
        let (workout, exercise, first, current) = (running.workout, running.exercise, running.first, running.current)
        let before = SessionSnapshot(workout, library: library)
        let setIDs = exercise.orderedSets.map(\.id)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: library, player: player)

        #expect(demo.open(exercise))
        #expect(demo.choices.map(\.equipment) == [[.dumbbell], [.kettlebell]])
        #expect(demo.selectedEquipment == [.dumbbell] && demo.viewed?.videoID == "TESTONLY001")
        let firstAttempt = demo.attempt
        player.send(.ready, attempt: firstAttempt)
        demo.play()
        player.send(.playing, attempt: firstAttempt)
        #expect(demo.phase == .playing)

        // No reviewed kettlebell match: the dumbbell video is stopped, not substituted.
        demo.select([.kettlebell])
        #expect(player.commands == ["load:TESTONLY001", "play", "stop"])
        #expect(demo.phase == .noVideo && demo.selectedEquipment == [.kettlebell])
        #expect(demo.association == nil && demo.viewed == nil)
        #expect(demo.cues == goblet.cues && demo.isPresented)
        player.send(.playing, attempt: firstAttempt)
        #expect(demo.phase == .noVideo, "The stopped video cannot resurface")
        demo.play()
        demo.retry()
        #expect(player.commands == ["load:TESTONLY001", "play", "stop"])
        // Choices outside the exercise's equipment are ignored.
        demo.select([.barbell])
        demo.select([.dumbbell, .kettlebell])
        #expect(demo.selectedEquipment == [.kettlebell] && player.commands.count == 3)

        // Returning loads the reviewed video stopped, and waits for an explicit Play.
        demo.select([.dumbbell])
        #expect(demo.phase == .loading && player.commands.last == "load:TESTONLY001")
        player.send(.ready, attempt: demo.attempt)
        #expect(demo.phase == .ready && player.commands.filter { $0 == "play" }.count == 1)
        demo.select([.dumbbell])
        #expect(player.commands.count == 4, "Choosing what is already shown changes nothing")

        #expect(!context.hasChanges)
        #expect(SessionSnapshot(workout, library: library) == before)
        #expect(exercise.exerciseID == "goblet-squat" && exercise.substitutedFromID == nil)
        #expect(exercise.orderedSets.map(\.id) == setIDs)
        #expect(WorkoutSession.currentSet(of: workout) === current)
        #expect(current.reps == 7 && current.weightKg == 12.5 && first.reps == 8 && first.isCompleted)
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(25)) == 35)
        demo.dismiss()
        #expect(player.commands.last == "stop" && demo.viewed == nil)
    }

    @Test func switchingEquipmentBetweenTwoReviewedVideosLeavesTheReplacementStopped() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let goblet = try #require(ExerciseLibrary.bundled.exercise(id: "goblet-squat"))
        let library = ExerciseLibrary(
            catalogVersion: 1, exercises: [goblet],
            demos: [
                synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001"),
                synthetic("goblet-squat", [.kettlebell], video: "TESTONLY002"),
            ])
        let workout = WorkoutSession.startAdHoc(title: "Two", in: context)
        let exercise = WorkoutSession.add(goblet, to: workout)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: library, player: player)
        #expect(demo.open(exercise))
        let firstAttempt = demo.attempt
        player.send(.ready, attempt: firstAttempt)
        demo.play()
        player.send(.playing, attempt: firstAttempt)
        demo.select([.kettlebell])
        #expect(player.commands == ["load:TESTONLY001", "play", "stop", "load:TESTONLY002"])
        #expect(demo.phase == .loading)
        #expect(
            demo.viewed
                == ViewedDemo(
                    exerciseID: "goblet-squat", exerciseName: "Goblet squat", equipment: [.kettlebell],
                    videoID: "TESTONLY002"))
        player.send(.playing, attempt: firstAttempt)
        player.send(.failed, attempt: firstAttempt)
        #expect(demo.phase == .loading, "Events from the replaced video are ignored")
        player.send(.ready, attempt: demo.attempt)
        #expect(demo.phase == .ready)
        #expect(player.commands.filter { $0 == "play" }.count == 1, "Replacement waits for explicit Play")

        // Leaving the app pauses; returning reloads the chosen variant, never the old one.
        demo.setSceneActive(false)
        demo.select([.dumbbell])
        #expect(demo.phase == .paused && player.commands.last == "stop")
        demo.setSceneActive(true)
        #expect(player.commands.last == "load:TESTONLY001")
        #expect(demo.viewed?.equipment == [.dumbbell])
        #expect(player.commands.filter { $0 == "play" }.count == 1)
    }
}
