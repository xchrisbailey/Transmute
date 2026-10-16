import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// The pending Health deletes: when they may run, what they leave behind, and how they end.
@MainActor
struct SessionLinkPendingDeleteTests {
    let rig: LinkRig
    var context: ModelContext { rig.context }
    var defaults: UserDefaults { rig.defaults }
    var pending: PendingHealthDeletes { PendingHealthDeletes(defaults: defaults) }

    init() throws {
        rig = try LinkRig()
    }

    /// The state a failed delete leaves: the iPhone saved P after the timeout, the watch's W
    /// arrived and linked the workout, and the delete of P failed. The entry waits in defaults.
    func pendingAfterFailedDelete(_ health: FakeHealth) async throws -> (workout: Workout, phonesID: UUID, watchID: UUID)
    {
        let workout = try rig.finishedOnPhone()
        let phone = rig.phone
        let saving = Task { try await phone.saveToHealth(workout, with: health, waitingForWatch: .seconds(5)) }
        await rig.clock.sleeperArrived()
        rig.clock.advance(by: .seconds(5))
        try await saving.value
        let phonesID = try #require(workout.healthKitWorkoutID)
        health.failDeletes(true)
        let watchID = health.recordOnWatch()
        await rig.watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await rig.flush()
        health.failDeletes(false)
        #expect(workout.healthKitWorkoutID == watchID)
        #expect(health.workouts == [phonesID, watchID])
        return (workout, phonesID, watchID)
    }

    /// A new launch: a fresh link over the same defaults.
    func relaunch(with health: any HealthService, in context: ModelContext) async {
        let relaunched = SessionLink(live: LoopbackWorkout(), device: .phone, clock: rig.clock, defaults: defaults)
        await relaunched.retryPendingDeletes(with: health, in: context)
    }

    @Test(.timeLimit(.minutes(1))) func aLaunchOnAStoreWithoutTheWorkoutLeavesBothHealthWorkoutsAlone() async throws {
        let health = FakeHealth()
        let (_, phonesID, watchID) = try await pendingAfterFailedDelete(health)

        // The persistent store failed to open, so the app launched on an empty fallback store.
        let fallback = try TransmuteStore.makeTestContainer()
        await relaunch(with: health, in: fallback.mainContext)

        #expect(health.workouts == [phonesID, watchID])
        #expect(pending.entries.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func aWorkoutDeletedInHistoryLosesBothHealthWorkoutsAtTheNextLaunch() async throws {
        let health = FakeHealth()
        let (workout, _, _) = try await pendingAfterFailedDelete(health)
        try WorkoutLog.delete(workout, in: context, defaults: defaults)

        await relaunch(with: health, in: context)

        #expect(health.workouts.isEmpty)
        #expect(pending.entries.isEmpty)
        #expect(pending.deletedWorkouts.isEmpty)
    }

    @Test func tombstonesKeepOnlyTheNewest() {
        let ids = (0..<PendingHealthDeletes.tombstoneLimit + 5).map { _ in UUID() }
        for id in ids { pending.markDeleted(id) }

        #expect(pending.deletedWorkouts == Array(ids.suffix(PendingHealthDeletes.tombstoneLimit)))
    }

    @Test(.timeLimit(.minutes(1))) func theIPhonesOwnCopyGoesBeforeTheWatchsAndIsNotHeldUpByIt() async throws {
        let health = FakeHealth()
        let (workout, phonesID, _) = try await pendingAfterFailedDelete(health)
        // The iPhone can't delete a workout the watch app wrote.
        let watchID = try #require(workout.healthKitWorkoutID)
        health.failDeletes(of: [watchID])
        try WorkoutLog.delete(workout, in: context, defaults: defaults)
        let before = health.deleteAttemptIDs.count

        await relaunch(with: health, in: context)

        #expect(health.deleteAttemptIDs.dropFirst(before) == [phonesID, watchID])
        #expect(health.workouts == [watchID])
        #expect(pending.entries == [.init(workoutID: workout.id, keep: watchID, remove: nil)])

        await relaunch(with: health, in: context)

        #expect(health.deleteAttemptIDs.dropFirst(before) == [phonesID, watchID, watchID])
        #expect(pending.entries.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func aFailedDeleteDoesNotStopTheOthersAndOnlyItStaysPending() async throws {
        let health = FakeHealth()
        let (workout, phonesID, _) = try await pendingAfterFailedDelete(health)
        health.failDeletes(of: [phonesID])
        try WorkoutLog.delete(workout, in: context, defaults: defaults)

        await relaunch(with: health, in: context)

        #expect(health.workouts == [phonesID])
        #expect(pending.entries == [.init(workoutID: workout.id, keep: nil, remove: phonesID)])
        #expect(pending.wasDeleted(workout.id))
    }
}
