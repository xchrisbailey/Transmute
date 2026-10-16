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
    private var held: CheckedContinuation<Void, Never>?
    private var saveStarted = false
    private var holds = false
    private var deleteFailures = false
    private var deleteCount = 0

    var isAvailable: Bool { true }
    var canSaveBodyweight: Bool { true }

    /// The workouts in Health right now.
    var workouts: Set<UUID> { lock.withLock { stored } }
    /// How many times the iPhone saved a workout, deleted or not.
    var saves: Int { lock.withLock { saveCount } }

    /// Makes `save` suspend until `releaseSave()`, so a test can decide what happens meanwhile.
    func holdSaves() { lock.withLock { holds = true } }

    /// Returns once a held save has begun.
    func saveBegan() async {
        while !lock.withLock({ saveStarted }), !Task.isCancelled { await Task.yield() }
    }

    func releaseSave() {
        lock.withLock {
            holds = false
            saveStarted = false
            let held = held
            self.held = nil
            return held
        }?.resume()
    }

    /// How many times `deleteWorkout` was called.
    var deleteAttempts: Int { lock.withLock { deleteCount } }

    /// Makes `deleteWorkout` throw until it's turned off.
    func failDeletes(_ fails: Bool) { lock.withLock { deleteFailures = fails } }

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
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let resume = lock.withLock {
                guard holds else { return true }
                saveStarted = true
                held = continuation
                return false
            }
            if resume { continuation.resume() }
        }
        return lock.withLock {
            let id = UUID()
            stored.insert(id)
            saveCount += 1
            return id
        }
    }

    func deleteWorkout(id: UUID) async throws {
        lock.withLock { deleteCount += 1 }
        if lock.withLock({ deleteFailures }) { throw HealthServiceError.notAuthorized }
        lock.withLock { _ = stored.remove(id) }
    }
}

final class Beats { var count = 0 }

/// A clock that only moves when a test says so, so a timeout never depends on how fast the run is.
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration
        func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
        func duration(to other: Instant) -> Duration { other.offset - offset }
        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
    }

    private struct Sleeper {
        let id: UUID
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [Sleeper] = []

    var now: Instant { lock.withLock { current } }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                lock.lock()
                if deadline <= current {
                    lock.unlock()
                    continuation.resume()
                } else {
                    sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
                    lock.unlock()
                }
            }
        } onCancel: {
            let cancelled = lock.withLock {
                let index = sleepers.firstIndex { $0.id == id }
                return index.map { sleepers.remove(at: $0) }
            }
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Returns once something is sleeping on the clock.
    func sleeperArrived() async {
        while lock.withLock({ sleepers.isEmpty }), !Task.isCancelled { await Task.yield() }
    }

    func advance(by duration: Duration) {
        let due = lock.withLock {
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.deadline <= current }
            sleepers.removeAll { $0.deadline <= current }
            return due
        }
        for sleeper in due { sleeper.continuation.resume() }
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
    let clock = ManualClock()
    let defaults = UserDefaults(suiteName: UUID().uuidString)!

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
        ends = (LoopbackWorkout(), LoopbackWorkout())
        ends.watch.peer = ends.phone
        ends.phone.peer = ends.watch
        watch = SessionLink(live: ends.watch, device: .watch, clock: clock, defaults: defaults)
        phone = SessionLink(live: ends.phone, device: .phone, clock: clock, defaults: defaults)
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
        for _ in 0..<2_000 where !done() {
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

    // MARK: Health hand-off

    /// A workout the iPhone owns and has finished, as it is when the watch starts to answer.
    func finishedOnPhone() throws -> Workout {
        let workout = try session()
        phone.own(workout, in: context)
        WorkoutSession.finish(workout, at: now.addingTimeInterval(600))
        phone.publish()
        return workout
    }

    let beats = Beats()

    /// Returns once the iPhone has handled everything the watch sent before this call: messages
    /// cross in order, and the iPhone handles them one at a time.
    func flush() async {
        beats.count += 1
        let bpm = Double(beats.count)
        watch.sendHeartRate(bpm)
        await settle { phone.remoteHeartRate == bpm }
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
        ends.phone.isMirroring = false
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
        ends.phone.isMirroring = false
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
