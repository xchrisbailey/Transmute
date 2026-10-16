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
    private var failingIDs: Set<UUID> = []
    private var deleteLog: [UUID] = []

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

    /// Every id `deleteWorkout` was called with, in order.
    var deleteAttemptIDs: [UUID] { lock.withLock { deleteLog } }

    /// Makes `deleteWorkout` throw for these ids, and only these, until it's called with none.
    func failDeletes(of ids: Set<UUID>) { lock.withLock { failingIDs = ids } }

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
        let fails = lock.withLock {
            deleteCount += 1
            deleteLog.append(id)
            return deleteFailures || failingIDs.contains(id)
        }
        if fails { throw HealthServiceError.notAuthorized }
        lock.withLock { _ = stored.remove(id) }
    }
}

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

/// Two linked ends over a loopback channel, with a clock and a defaults suite of their own.
@MainActor
final class LinkRig {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let watch: SessionLink
    let phone: SessionLink
    let ends: (watch: LoopbackWorkout, phone: LoopbackWorkout)
    let clock = ManualClock()
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    private var beats = 0

    init() throws {
        container = try TransmuteStore.makeTestContainer()
        ends = (LoopbackWorkout(), LoopbackWorkout())
        ends.watch.peer = ends.phone
        ends.phone.peer = ends.watch
        watch = SessionLink(live: ends.watch, device: .watch, clock: clock, defaults: defaults)
        phone = SessionLink(live: ends.phone, device: .phone, clock: clock, defaults: defaults)
        let (watch, phone) = (watch, phone)
        Task { await watch.run() }
        Task { await phone.run() }
    }

    /// A workout the iPhone owns and has finished, as it is when the watch starts to answer.
    func finishedOnPhone() throws -> Workout {
        let workout = try session()
        phone.own(workout, in: context)
        WorkoutSession.finish(workout, at: now.addingTimeInterval(600))
        phone.publish()
        return workout
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

    /// Returns once the iPhone has handled everything the watch sent before this call: messages
    /// cross in order, and the iPhone handles them one at a time.
    func flush() async {
        beats += 1
        let bpm = Double(beats)
        watch.sendHeartRate(bpm)
        await settle { phone.remoteHeartRate == bpm }
    }
}

/// A channel whose `send` never returns until `release()`, as when the iPhone is out of reach.
@MainActor
@Observable
final class StuckWorkout: LiveWorkout {
    let state = LiveWorkoutState.running
    let heartRate: Double? = nil
    let averageHeartRate: Double? = nil
    let activeEnergyKcal: Double? = nil
    var isMirroring = true
    let incoming = AsyncStream<Data> { _ in }
    private var held: CheckedContinuation<Void, Never>?

    func start(activity: HealthActivity, at date: Date) async throws {}
    func pause() {}
    func resume() {}
    func send(_ data: Data) async {
        await withCheckedContinuation { held = $0 }
    }
    func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID? { nil }
    func discard() async {}

    func release() {
        held?.resume()
        held = nil
    }
}
