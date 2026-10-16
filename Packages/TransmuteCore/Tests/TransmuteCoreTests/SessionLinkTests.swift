import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct SessionLinkTests {
    let rig: LinkRig
    var context: ModelContext { rig.context }
    var now: Date { rig.now }
    var watch: SessionLink { rig.watch }
    var phone: SessionLink { rig.phone }

    init() throws {
        rig = try LinkRig()
    }

    func session() throws -> Workout { try rig.session() }

    func settle(until done: () -> Bool = { false }) async { await rig.settle(until: done) }

    @Test func owningMarksTheWorkoutAndShowsItOnTheOtherDevice() async throws {
        let workout = try session()
        watch.own(workout, in: context)
        #expect(workout.startedOn == .watch)
        await settle { phone.mirrored != nil }
        #expect(phone.mirrored == SessionSnapshot(workout))
        #expect(watch.mirrored == nil)
    }

    @Test func aSetLoggedOnTheMirrorIsSavedByTheOwner() async throws {
        let workout = try session()
        watch.own(workout, in: context)
        await settle { phone.mirrored != nil }
        let ref = try #require(phone.mirrored?.current)
        var applied: [SessionCommand] = []
        watch.onCommand = { command, _ in applied.append(command) }

        phone.send(.logSet(ref, SetValues(weightKg: 82.5, reps: 5), at: now))
        #expect(phone.mirrored?.set(at: ref)?.isCompleted == true)

        await settle { !applied.isEmpty }
        let set = try #require(workout.orderedExercises.first?.orderedSets.first)
        #expect(set.isCompleted)
        #expect(set.weightKg == 82.5)
        await settle { phone.mirrored == SessionSnapshot(workout) }
        #expect(phone.mirrored == SessionSnapshot(workout))
    }

    @Test func localChangesReachTheMirrorWhenPublished() async throws {
        let workout = try session()
        phone.own(workout, in: context)
        await settle { watch.mirrored != nil }
        let set = try #require(WorkoutSession.currentSet(of: workout))
        WorkoutSession.complete(set, in: workout, at: now)
        phone.publish()
        await settle { watch.mirrored?.exercises.first?.sets.first?.isCompleted == true }
        #expect(watch.mirrored == SessionSnapshot(workout))
    }

    @Test func commandsForAnotherWorkoutAreIgnored() async throws {
        let workout = try session()
        watch.own(workout, in: context)
        let ref = SetRef(exerciseOrder: 0, setOrder: 0)
        await watch.handle(.command(.logSet(ref, SetValues(reps: 5), at: now), workoutID: UUID()))
        #expect(workout.orderedExercises.first?.orderedSets.first?.isCompleted == false)
    }

    @Test func finishingOnTheMirrorEndsTheOwnersWorkoutAndKeepsTheSummaryUp() async throws {
        let workout = try session()
        phone.own(workout, in: context)
        await settle { watch.mirrored != nil }
        watch.send(.finish(at: now.addingTimeInterval(600)))
        await settle { workout.endedAt != nil }
        #expect(workout.endedAt == now.addingTimeInterval(600))
        #expect(phone.ownedID == nil)
        await settle { watch.mirrored?.isFinished == true }
        #expect(watch.mirrored?.isFinished == true)
    }

    @Test func theWatchsHealthWorkoutIsKeptOnThePhonesWorkout() async throws {
        let workout = try session()
        phone.own(workout, in: context)
        WorkoutSession.finish(workout, at: now.addingTimeInterval(600))
        phone.publish()
        let healthID = UUID()
        await watch.ended(workoutID: workout.id, healthWorkoutID: healthID)
        await settle { workout.healthKitWorkoutID != nil }
        #expect(workout.healthKitWorkoutID == healthID)
    }

    @Test func aDiscardedSessionLeavesTheMirror() async throws {
        let workout = try session()
        watch.own(workout, in: context)
        await settle { phone.mirrored != nil }
        WorkoutSession.discard(workout, in: context)
        watch.discarded()
        await settle { phone.mirrored == nil }
        #expect(phone.mirrored == nil)
    }

    @Test func aLateJoinerAsksForTheSnapshot() async throws {
        let workout = try session()
        phone.own(workout, in: context)
        await settle { watch.mirrored != nil }
        watch.dismissMirrored()
        watch.requestSnapshot()
        await settle { watch.mirrored != nil }
        #expect(watch.mirrored?.workoutID == workout.id)
    }

    @Test func heartRateCrossesToThePhone() async {
        watch.sendHeartRate(132, at: now)
        await settle { phone.remoteHeartRate != nil }
        #expect(phone.remoteHeartRate == 132)
    }
}
