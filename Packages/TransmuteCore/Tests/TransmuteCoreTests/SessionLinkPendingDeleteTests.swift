import Foundation
import SwiftData
import Testing
import TransmuteTestSupport

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

    @Test func entriesStoredUnderTheOldKeysStillDecode() throws {
        let workoutID = UUID()
        let watchID = UUID()
        let phonesID = UUID()
        let both = #"{"workoutID":"\#(workoutID)","keep":"\#(watchID)","remove":"\#(phonesID)"}"#
        let phoneOnly = #"{"workoutID":"\#(workoutID)","remove":"\#(phonesID)"}"#

        let entries = try JSONDecoder().decode(
            [PendingHealthDeletes.Entry].self, from: Data("[\(both),\(phoneOnly)]".utf8))

        #expect(
            entries == [
                .init(workoutID: workoutID, watchHealthID: watchID, phoneHealthID: phonesID),
                .init(workoutID: workoutID, watchHealthID: nil, phoneHealthID: phonesID),
            ])
        let rewritten = try JSONSerialization.jsonObject(with: JSONEncoder().encode(entries[0]))
        let keys = try #require(rewritten as? [String: Any]).keys
        #expect(Set(keys) == ["workoutID", "keep", "remove"])
    }

    struct Left {
        let workout: Workout
        let phonesID: UUID
        let watchID: UUID
    }

    /// The state a failed delete leaves: the iPhone saved P after the timeout, the watch's W
    /// arrived and linked the workout, and the delete of P failed. The entry waits in defaults.
    func pendingAfterFailedDelete(_ health: FakeHealth) async throws -> Left {
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
        return Left(workout: workout, phonesID: phonesID, watchID: watchID)
    }

    /// A new launch: a fresh link over the same defaults.
    func relaunch(with health: any HealthService, in context: ModelContext) async {
        let relaunched = SessionLink(live: LoopbackWorkout(), device: .phone, clock: rig.clock, defaults: defaults)
        await relaunched.retryPendingDeletes(with: health, in: context)
    }

    func fetch(_ id: UUID) throws -> Workout? {
        try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })).first
    }

    /// A backup of the store as it is now, to restore the workout from once it's deleted.
    func backup() throws -> Data {
        try DataTransfer.exportBackup(from: context)
    }

    @Test(.timeLimit(.minutes(1))) func aLaunchOnAStoreWithoutTheWorkoutLeavesBothHealthWorkoutsAlone() async throws {
        let health = FakeHealth()
        let left = try await pendingAfterFailedDelete(health)
        let (phonesID, watchID) = (left.phonesID, left.watchID)

        // The persistent store failed to open, so the app launched on an empty fallback store.
        let fallback = try TransmuteStore.makeTestContainer()
        await relaunch(with: health, in: fallback.mainContext)

        #expect(health.workouts == [phonesID, watchID])
        #expect(pending.entries.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func aWorkoutDeletedInHistoryLosesBothHealthWorkoutsAtTheNextLaunch() async throws {
        let health = FakeHealth()
        let workout = try await pendingAfterFailedDelete(health).workout
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
        let left = try await pendingAfterFailedDelete(health)
        let (workout, phonesID) = (left.workout, left.phonesID)
        // The iPhone can't delete a workout the watch app wrote.
        let watchID = try #require(workout.healthKitWorkoutID)
        health.failDeletes(of: [watchID])
        try WorkoutLog.delete(workout, in: context, defaults: defaults)
        let before = health.deleteAttemptIDs.count

        await relaunch(with: health, in: context)

        #expect(health.deleteAttemptIDs.dropFirst(before) == [phonesID, watchID])
        #expect(health.workouts == [watchID])
        #expect(pending.entries == [.init(workoutID: workout.id, watchHealthID: watchID, phoneHealthID: nil)])

        await relaunch(with: health, in: context)

        #expect(health.deleteAttemptIDs.dropFirst(before) == [phonesID, watchID, watchID])
        #expect(pending.entries.count == 1)
    }

    @Test(.timeLimit(.minutes(1))) func aFailedDeleteDoesNotStopTheOthersAndOnlyItStaysPending() async throws {
        let health = FakeHealth()
        let left = try await pendingAfterFailedDelete(health)
        let (workout, phonesID) = (left.workout, left.phonesID)
        health.failDeletes(of: [phonesID])
        try WorkoutLog.delete(workout, in: context, defaults: defaults)

        await relaunch(with: health, in: context)

        #expect(health.workouts == [phonesID])
        #expect(pending.entries == [.init(workoutID: workout.id, watchHealthID: nil, phoneHealthID: phonesID)])
        #expect(pending.wasDeleted(workout.id))
    }

    @Test(.timeLimit(.minutes(1))) func aRestoredWorkoutKeepsTheWatchsCopyOnAFallbackLaunch() async throws {
        let health = FakeHealth()
        let left = try await pendingAfterFailedDelete(health)
        let (workoutID, phonesID, watchID) = (left.workout.id, left.phonesID, left.watchID)
        let saved = try backup()
        try WorkoutLog.delete(left.workout, in: context, defaults: defaults)
        #expect(pending.wasDeleted(workoutID))

        try DataTransfer.importBackup(saved, into: context, defaults: defaults)

        #expect(try fetch(workoutID)?.healthKitWorkoutID == watchID)
        #expect(!pending.wasDeleted(workoutID))

        // The next launch falls back to an empty store, which doesn't have the workout.
        let fallback = try TransmuteStore.makeTestContainer()
        await relaunch(with: health, in: fallback.mainContext)

        #expect(health.workouts == [phonesID, watchID])
        #expect(try fetch(workoutID)?.healthKitWorkoutID == watchID)
    }

    @Test(.timeLimit(.minutes(1))) func aHalfDonePassThenARestoreStillDeletesTheIPhonesCopy() async throws {
        let health = FakeHealth()
        let left = try await pendingAfterFailedDelete(health)
        let saved = try backup()
        health.failDeletes(of: [left.phonesID])
        try WorkoutLog.delete(left.workout, in: context, defaults: defaults)
        await relaunch(with: health, in: context)
        #expect(
            pending.entries == [.init(workoutID: left.workout.id, watchHealthID: nil, phoneHealthID: left.phonesID)])
        health.failDeletes(of: [])

        try DataTransfer.importBackup(saved, into: context, defaults: defaults)
        await relaunch(with: health, in: context)

        // The watch's copy went in the half-done pass; the iPhone's follows now.
        #expect(health.workouts.isEmpty)
        #expect(pending.entries.isEmpty)
    }
}
