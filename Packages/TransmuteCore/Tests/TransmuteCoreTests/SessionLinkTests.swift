import Foundation
import Observation
import SwiftData
import Testing

@testable import TransmuteCore

/// One end of a pretend data channel: what it sends arrives in its peer's `incoming`.
@MainActor
@Observable
final class LoopbackWorkout: LiveWorkout {
    let state = LiveWorkoutState.running
    let heartRate: Double? = nil
    let averageHeartRate: Double? = nil
    let activeEnergyKcal: Double? = nil
    let isMirroring = true
    let incoming: AsyncStream<Data>
    private let inbox: AsyncStream<Data>.Continuation
    weak var peer: LoopbackWorkout?

    init() {
        (incoming, inbox) = AsyncStream.makeStream(of: Data.self)
    }

    func start(activity: HealthActivity, at date: Date) async throws {}
    func pause() {}
    func resume() {}
    func send(_ data: Data) async { peer?.inbox.yield(data) }
    func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID? { nil }
    func discard() async {}
}

@MainActor
struct SessionLinkTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let watch: SessionLink
    let phone: SessionLink
    let ends: (watch: LoopbackWorkout, phone: LoopbackWorkout)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        ends = (LoopbackWorkout(), LoopbackWorkout())
        ends.watch.peer = ends.phone
        ends.phone.peer = ends.watch
        watch = SessionLink(live: ends.watch, device: .watch)
        phone = SessionLink(live: ends.phone, device: .phone)
        let (watch, phone) = (watch, phone)
        Task { await watch.run() }
        Task { await phone.run() }
    }

    func session() throws -> Workout {
        let (_, plan) = SampleData.insert(into: context, now: now)
        try context.save()
        let day = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        return WorkoutSession.start(day, at: now, in: context)
    }

    /// Lets the queued messages cross and be handled.
    func settle(until done: () -> Bool = { false }) async {
        for _ in 0..<200 where !done() {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

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
        // The mirror shows it at once, before the owner has answered.
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
        watch.ended(workoutID: workout.id, healthWorkoutID: healthID)
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
