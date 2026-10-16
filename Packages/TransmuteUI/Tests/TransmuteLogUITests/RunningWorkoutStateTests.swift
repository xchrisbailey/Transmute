import Testing
import TransmuteCore

@testable import TransmuteLogUI

@MainActor
struct RunningWorkoutStateTests {
    @Test func noRunningWorkoutHasNothingToResume() {
        #expect(RunningWorkoutState(running: nil, device: .phone, session: nil) == .none)
    }

    @Test func aWorkoutTheWatchStartedStaysTheWatchs() {
        let workout = Workout(title: "Pull")
        workout.startedOn = .watch
        #expect(RunningWorkoutState(running: workout, device: .phone, session: nil) == .ownedElsewhere(workout))
        #expect(RunningWorkoutState(running: workout, device: .mac, session: nil) == .ownedElsewhere(workout))
        #expect(RunningWorkoutState(running: workout, device: .watch, session: nil) == .resumable(workout))
    }

    @Test func aSessionAlreadyOnScreenIsNotResumedTwice() {
        let workout = Workout(title: "Push")
        #expect(RunningWorkoutState(running: workout, device: .phone, session: workout) == .onScreen)
    }

    @Test func anOrdinaryRunningWorkoutResumes() {
        let unmarked = Workout(title: "Legs")
        let phones = Workout(title: "Arms")
        phones.startedOn = .phone
        #expect(RunningWorkoutState(running: unmarked, device: .phone, session: nil) == .resumable(unmarked))
        #expect(RunningWorkoutState(running: phones, device: .mac, session: nil) == .resumable(phones))
    }
}
