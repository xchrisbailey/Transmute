import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteTestSupport

@testable import TransmuteLogUI

@MainActor
struct SessionDemoTests {
    @Test func unsupportedExercisesNeverLoadAPlayer() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let library = ExerciseLibrary.bundled
        let workout = WorkoutSession.startAdHoc(title: "Unsupported", in: context)
        let exercise = WorkoutSession.add(try #require(library.exercise(id: "back-squat")), to: workout)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: library, player: player)
        #expect(!demo.open(exercise))
        demo.play()
        demo.retry()
        demo.dismiss()
        #expect(player.commands.isEmpty)
        #expect(!demo.isPresented)
    }

    @Test func viewingADemoLeavesTheRunningWorkoutAndElapsedRestAlone() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let library = ExerciseLibrary.bundled
        let pushUp = try #require(library.exercise(id: "push-up"))
        // This deliberately synthetic association is never part of bundled content.
        let fixture = ExerciseDemo(
            exerciseID: "push-up", equipment: [.bodyweight], videoID: "TESTONLY001",
            reviewedBy: "Test fixture only", reviewedOn: "2026-11-04",
            movementReview: "Fixture", mutedReview: "Fixture", captions: .notNeeded, captionReview: nil)
        let content = ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [fixture])
        let workout = WorkoutSession.startAdHoc(title: "Demo test", at: now, in: context)
        let exercise = WorkoutSession.add(pushUp, to: workout, sets: 3)
        let first = exercise.orderedSets[0]
        first.reps = 8
        first.restSeconds = 60
        WorkoutSession.complete(first, in: workout, at: now)
        let current = try #require(WorkoutSession.currentSet(of: workout))
        current.reps = 7
        current.weightKg = 12.5
        try context.save()
        let before = SessionSnapshot(workout, library: content)
        let player = DemoPlayerSpy()
        let demo = SessionDemo(workout: workout, library: content, player: player)

        #expect(demo.open(exercise))
        #expect(demo.cues == pushUp.cues)
        #expect(demo.phase == .loading)
        #expect(player.commands == ["load:TESTONLY001"])
        exerciseLifecycle(demo, player: player)
        #expect(!context.hasChanges)
        #expect(SessionSnapshot(workout, library: content) == before)
        #expect(WorkoutSession.currentSet(of: workout) === current)
        #expect(current.reps == 7 && current.weightKg == 12.5)
        #expect(first.reps == 8 && first.isCompleted)
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(25)) == 35)
        #expect(WorkoutSession.restRemaining(in: workout, at: now.addingTimeInterval(61)) == nil)
        let restored = ModelContext(container)
        let persisted = try #require(try WorkoutSession.current(in: restored))
        #expect(persisted.id == workout.id)
        #expect(persisted.orderedExercises[0].orderedSets.map(\.id) == exercise.orderedSets.map(\.id))
        workout.startedOn = .mac
        #expect(!demo.open(exercise), "Viewing must not expand to a workout owned by another device")
    }

    private func exerciseLifecycle(_ demo: SessionDemo, player: DemoPlayerSpy) {
        let initialAttempt = demo.attempt
        player.send(.ready, attempt: initialAttempt)
        demo.play()
        player.send(.playing, attempt: initialAttempt)
        #expect(demo.phase == .playing)
        demo.setSceneActive(false)
        #expect(demo.phase == .paused)
        #expect(player.commands.last == "pause")
        player.send(.playing, attempt: initialAttempt)
        #expect(demo.phase == .paused)
        demo.setSceneActive(true)
        #expect(player.commands.last == "load:TESTONLY001")
        player.send(.ready, attempt: demo.attempt)
        #expect(demo.phase == .ready)
        #expect(player.commands.filter { $0 == "play" }.count == 1)
        demo.play()
        demo.setInterrupted(true)
        demo.setSceneActive(false)
        demo.setInterrupted(false)
        #expect(demo.phase == .paused)
        demo.setSceneActive(true)
        player.send(.failed, attempt: demo.attempt)
        #expect(demo.phase == .unavailable)
        #expect(!demo.cues.isEmpty)
        demo.retry()
        player.send(.failed, attempt: initialAttempt)
        #expect(demo.phase == .loading, "Old player events cannot fail a retry")
        player.send(.ready, attempt: demo.attempt)
        demo.dismiss()
        #expect(player.commands.last == "stop")
        #expect(!demo.isPresented)
    }
}

@MainActor
private final class DemoPlayerSpy: DemoPlayer {
    var onEvent: ((DemoPlayerEvent, UUID) -> Void)?
    var commands: [String] = []

    func load(videoID: String, attempt: UUID) { commands.append("load:\(videoID)") }
    func play() { commands.append("play") }
    func pause() { commands.append("pause") }
    func stop() { commands.append("stop") }
    func send(_ event: DemoPlayerEvent, attempt: UUID) { onEvent?(event, attempt) }
}
