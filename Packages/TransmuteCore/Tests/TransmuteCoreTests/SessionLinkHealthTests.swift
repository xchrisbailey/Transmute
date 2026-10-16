import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct SessionLinkHealthTests {
    let rig: LinkRig
    var context: ModelContext { rig.context }
    var watch: SessionLink { rig.watch }
    var phone: SessionLink { rig.phone }
    var clock: ManualClock { rig.clock }
    var defaults: UserDefaults { rig.defaults }

    init() throws {
        rig = try LinkRig()
    }

    func settle(until done: () -> Bool = { false }) async { await rig.settle(until: done) }
    func flush() async { await rig.flush() }

    /// A workout the iPhone owns and has finished, as it is when the watch starts to answer.
    func finishedOnPhone() throws -> Workout {
        let workout = try rig.session()
        phone.own(workout, in: context)
        WorkoutSession.finish(workout, at: rig.now.addingTimeInterval(600))
        phone.publish()
        return workout
    }

    /// Starts saving and returns once the iPhone is waiting on the watch.
    func startSaving(_ workout: Workout, with health: any HealthService, timeout: Duration = .seconds(5)) async
        -> Task<Void, any Error>
    {
        let phone = phone
        let saving = Task { try await phone.saveToHealth(workout, with: health, waitingForWatch: timeout) }
        await clock.sleeperArrived()
        return saving
    }

    @Test(.timeLimit(.minutes(1))) func theWatchsIDArrivingInTimeIsAdoptedAndTheIPhoneSavesNothing() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        let saving = await startSaving(workout, with: health)

        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        try await saving.value

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func theWatchsIDArrivingBeforeTheWaitBeginsIsAdopted() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await settle { workout.healthKitWorkoutID != nil }

        try await phone.saveToHealth(workout, with: health)

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func aNilFromTheWatchEndsTheWaitAtOnceAndTheIPhoneSavesItsOwn() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)

        await watch.ended(workoutID: workout.id, healthWorkoutID: nil)
        try await saving.value

        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test(.timeLimit(.minutes(1))) func aTimedOutWaitLeavesTheIPhoneToSaveItsOwn() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health, timeout: .seconds(5))

        clock.advance(by: .seconds(5))
        try await saving.value

        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test(.timeLimit(.minutes(1))) func theWaitStillHappensAfterTheWatchsSessionClosed() async throws {
        let workout = try finishedOnPhone()
        // The watch ends its session when it sees the finish, before the person taps Save.
        rig.ends.phone.isMirroring = false
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        let saving = await startSaving(workout, with: health)

        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        try await saving.value

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func aWorkoutTheWatchNeverRecordedIsSavedWithoutWaiting() async throws {
        rig.ends.phone.isMirroring = false
        let workout = try finishedOnPhone()
        let health = FakeHealth()

        try await phone.saveToHealth(workout, with: health)

        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test(.timeLimit(.minutes(1))) func aLateIDReplacesTheIPhonesHealthWorkoutWithTheWatchs() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        let phonesID = try #require(workout.healthKitWorkoutID)

        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()

        #expect(workout.healthKitWorkoutID == watchID)
        #expect(health.workouts == [watchID])
        #expect(!health.workouts.contains(phonesID))
    }

    @Test(.timeLimit(.minutes(1))) func anIDArrivingWhileTheIPhoneIsSavingLeavesOnlyTheWatchs() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        health.holdSaves()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        await health.saveBegan()

        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()
        health.releaseSave()
        try await saving.value

        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func aNilArrivingAfterTheIPhoneSavedChangesNothing() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        let phonesID = workout.healthKitWorkoutID

        await watch.ended(workoutID: workout.id, healthWorkoutID: nil)
        await flush()

        #expect(workout.healthKitWorkoutID == phonesID)
        #expect(health.workouts.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func aFailedDeleteIsRetriedWhenTheWatchAnswersAgain() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        let phonesID = try #require(workout.healthKitWorkoutID)
        health.failDeletes(true)
        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()
        #expect(workout.healthKitWorkoutID == watchID)
        #expect(health.workouts == [phonesID, watchID])

        health.failDeletes(false)
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()

        #expect(health.workouts == [watchID])
    }

    @Test(.timeLimit(.minutes(1))) func aDeleteLeftUndoneByAKillIsFinishedAtTheNextLaunch() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        health.failDeletes(true)
        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()
        #expect(health.workouts.count == 2)

        // A new launch: a fresh link over the same defaults.
        health.failDeletes(false)
        let relaunched = SessionLink(live: LoopbackWorkout(), device: .phone, clock: clock, defaults: defaults)
        await relaunched.retryPendingDeletes(with: health, in: context)

        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func aFinishedDeleteIsNotAttemptedAgainAtTheNextLaunch() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()
        let attempts = health.deleteAttempts
        #expect(attempts == 1)

        let relaunched = SessionLink(live: LoopbackWorkout(), device: .phone, clock: clock, defaults: defaults)
        await relaunched.retryPendingDeletes(with: health, in: context)

        #expect(health.deleteAttempts == attempts)
    }

    @Test(.timeLimit(.minutes(1))) func aLateIDForADeletedWorkoutRemovesTheWatchsHealthWorkout() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let saving = await startSaving(workout, with: health)
        clock.advance(by: .seconds(5))
        try await saving.value
        let phonesID = try #require(workout.healthKitWorkoutID)

        // What History does when the person deletes the workout.
        let removed = try WorkoutLog.delete(workout, in: context)
        try await health.deleteWorkout(id: try #require(removed))
        #expect(removed == phonesID)
        let watchID = health.recordOnWatch()
        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await flush()

        #expect(health.workouts.isEmpty)
    }

    @Test(.timeLimit(.minutes(1))) func aSecondSaveWhileTheFirstWaitsJoinsIt() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        let first = await startSaving(workout, with: health)
        let second = await startSaving(workout, with: health)

        await watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        try await first.value
        try await second.value

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }
}
