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
    var isMirroring = true
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

/// A Health store that keeps the workouts saved to it, so a test can count what's left.
final class FakeHealth: HealthService, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Set<UUID> = []
    private var saveCount = 0
    var saveDelay: Duration = .zero

    var isAvailable: Bool { true }
    var canSaveBodyweight: Bool { true }

    /// The workouts in Health right now.
    var workouts: Set<UUID> { lock.withLock { stored } }
    /// How many times the iPhone saved a workout, deleted or not.
    var saves: Int { lock.withLock { saveCount } }

    /// A workout the watch recorded, whose id it then sends to the iPhone.
    func recordOnWatch() -> UUID {
        let id = UUID()
        lock.withLock { _ = stored.insert(id) }
        return id
    }

    func requestAccess(_ scope: HealthAccessScope) async throws {}
    func accessStatus() async -> HealthAccessStatus { HealthAccessStatus() }
    func bodyMetrics() async -> HealthBodyMetrics { HealthBodyMetrics() }
    func bodyweights(since date: Date) async -> [HealthBodyweight] { [] }
    func restingHeartRate() async -> Double? { nil }
    func vo2Max() async -> Double? { nil }
    func otherWorkouts(in interval: DateInterval) async -> [OtherWorkout] { [] }
    func saveBodyweight(kg: Double, at date: Date) async throws -> UUID { UUID() }

    func save(_ workout: HealthWorkoutRecord) async throws -> UUID {
        try await Task.sleep(for: saveDelay)
        return lock.withLock {
            let id = UUID()
            stored.insert(id)
            saveCount += 1
            return id
        }
    }

    func deleteWorkout(id: UUID) async throws {
        lock.withLock { _ = stored.remove(id) }
    }
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

    // MARK: Health hand-off

    /// A workout the iPhone owns and has finished, as it is when the watch starts to answer.
    func finishedOnPhone() throws -> Workout {
        let workout = try session()
        phone.own(workout, in: context)
        WorkoutSession.finish(workout, at: now.addingTimeInterval(600))
        phone.publish()
        return workout
    }

    /// Sends the watch's answer once the iPhone has started waiting for it.
    func watchReplies(_ workout: Workout, with id: UUID?, after delay: Duration = .milliseconds(30)) {
        let watch = watch
        Task {
            try? await Task.sleep(for: delay)
            watch.ended(workoutID: workout.id, healthWorkoutID: id)
        }
    }

    @Test func theWatchsIDArrivingInTimeIsAdoptedAndTheIPhoneSavesNothing() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        watchReplies(workout, with: watchID)

        try await phone.saveToHealth(workout, with: health, waitingForWatch: .seconds(120))

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test func theWatchsIDArrivingBeforeTheWaitBeginsIsAdopted() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        let watchID = health.recordOnWatch()
        watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await settle { workout.healthKitWorkoutID != nil }

        try await phone.saveToHealth(workout, with: health, waitingForWatch: .seconds(120))

        #expect(health.saves == 0)
        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test func aNilFromTheWatchEndsTheWaitAtOnceAndTheIPhoneSavesItsOwn() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        watchReplies(workout, with: nil, after: .milliseconds(10))

        let started = ContinuousClock.now
        try await phone.saveToHealth(workout, with: health, waitingForWatch: .seconds(120))

        #expect(ContinuousClock.now - started < .seconds(60))
        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test func aTimedOutWaitLeavesTheIPhoneToSaveItsOwn() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()

        try await phone.saveToHealth(workout, with: health, waitingForWatch: .milliseconds(50))

        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test func aLateIDReplacesTheIPhonesHealthWorkoutWithTheWatchs() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        try await phone.saveToHealth(workout, with: health, waitingForWatch: .milliseconds(20))
        let phonesID = try #require(workout.healthKitWorkoutID)

        let watchID = health.recordOnWatch()
        watch.ended(workoutID: workout.id, healthWorkoutID: watchID)
        await settle { workout.healthKitWorkoutID == watchID }

        #expect(workout.healthKitWorkoutID == watchID)
        await settle { health.workouts == [watchID] }
        #expect(health.workouts == [watchID])
        #expect(!health.workouts.contains(phonesID))
    }

    @Test func anIDArrivingWhileTheIPhoneIsSavingLeavesOnlyTheWatchs() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        health.saveDelay = .milliseconds(150)
        let watchID = health.recordOnWatch()
        watchReplies(workout, with: watchID, after: .milliseconds(100))

        try await phone.saveToHealth(workout, with: health, waitingForWatch: .milliseconds(20))

        #expect(health.workouts == [watchID])
        #expect(workout.healthKitWorkoutID == watchID)
    }

    @Test func aWatchThatNeverRepliesLeavesTheIPhonesWorkoutAlone() async throws {
        let workout = try finishedOnPhone()
        ends.phone.isMirroring = false
        let health = FakeHealth()

        let started = ContinuousClock.now
        try await phone.saveToHealth(workout, with: health, waitingForWatch: .seconds(120))
        await settle()

        #expect(ContinuousClock.now - started < .seconds(60))
        #expect(health.saves == 1)
        #expect(health.workouts.count == 1)
        #expect(workout.healthKitWorkoutID.map { health.workouts.contains($0) } == true)
    }

    @Test func aNilArrivingAfterTheIPhoneSavedChangesNothing() async throws {
        let workout = try finishedOnPhone()
        let health = FakeHealth()
        try await phone.saveToHealth(workout, with: health, waitingForWatch: .milliseconds(20))
        let phonesID = workout.healthKitWorkoutID

        watch.ended(workoutID: workout.id, healthWorkoutID: nil)
        await settle()

        #expect(workout.healthKitWorkoutID == phonesID)
        #expect(health.workouts.count == 1)
    }
}
