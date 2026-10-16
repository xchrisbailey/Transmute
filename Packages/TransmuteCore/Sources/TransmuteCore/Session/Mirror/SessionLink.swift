import Foundation
import OSLog
import Observation  // swiftlint:disable:this sorted_imports
import SwiftData

/// Keeps a session in step between the iPhone and the watch, over the live workout's
/// data channel. The device that started the workout owns it and saves it; the other one shows
/// the owner's snapshot and sends commands back, which the owner applies and answers with a
/// fresh snapshot.
@MainActor
@Observable
public final class SessionLink {
    /// The session the other device is running, while it's connected.
    public private(set) var mirrored: SessionSnapshot?
    /// The heart rate the watch last sent, for the iPhone.
    public private(set) var remoteHeartRate: Double?
    /// Called on the owner after a command from the other device was applied, to check records
    /// and refresh the screen.
    public var onCommand: ((SessionCommand, SessionMirror.Outcome) -> Void)?

    public let live: any LiveWorkout
    public let device: SessionDevice

    private struct Owned {
        let workout: Workout
        let context: ModelContext
        let library: ExerciseLibrary
    }

    private var owned: Owned?

    /// What the watch said about Health for the workout this device ended last.
    private enum WatchReply: Equatable {
        case healthWorkout(UUID)
        case nothingSaved
    }

    /// The Health side of the workout this device ended last. It outlives `owned`, so the
    /// watch's answer can still land after the workout ended.
    @MainActor
    private final class Ending {
        let workoutID: UUID
        let context: ModelContext?
        /// Whether the watch was recording this workout when it ended, so it will answer with a
        /// Health id or a `nil`. This is a fact about the workout, not about the connection now:
        /// the watch's session may have closed by the time the person taps Save.
        let expectsWatchReply: Bool
        var health: (any HealthService)?
        var reply: WatchReply?
        /// The Health workout the iPhone saved itself, until the watch's replaces it.
        var phoneSaved: UUID?
        /// The save in flight, so a second call joins it instead of starting another.
        var saving: Task<Void, any Error>?
        private var waiter: CheckedContinuation<Void, Never>?
        private var timer: Task<Void, Never>?

        init(workoutID: UUID, context: ModelContext?, expectsWatchReply: Bool) {
            self.workoutID = workoutID
            self.context = context
            self.expectsWatchReply = expectsWatchReply
        }

        /// Returns when the watch answers, or after `timeout` on `clock`.
        func awaitReply(timeout: Duration, clock: any Clock<Duration>) async {
            guard reply == nil else { return }
            await withCheckedContinuation { continuation in
                waiter = continuation
                timer = Task {
                    try? await clock.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    resumeWaiter()
                }
            }
        }

        func resumeWaiter() {
            timer?.cancel()
            timer = nil
            waiter?.resume()
            waiter = nil
        }
    }

    /// A Health workout still to remove, kept in `defaults` until Health has done it, so a failed
    /// delete or a kill between linking and deleting is picked up by a later pass.
    private struct PendingDelete: Codable, Equatable {
        let workoutID: UUID
        /// The Health workout the Transmute workout ends up linked to.
        let keep: UUID
        /// The iPhone's own Health workout, which `keep` replaces.
        let remove: UUID?
    }

    private var ending: Ending?

    private let clock: any Clock<Duration>
    private let defaults: UserDefaults
    private static let pendingKey = "link.pendingHealthDeletes"

    private var pending: [PendingDelete] {
        get { defaults.data(forKey: Self.pendingKey).flatMap { try? JSONDecoder().decode([PendingDelete].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.pendingKey) }
    }

    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "link")

    /// Messages go out one at a time, so a newer snapshot never lands before an older one.
    private let outbox: AsyncStream<Outgoing>.Continuation

    private struct Outgoing {
        let data: Data
        /// Called once the message has been handed to the channel.
        var sent: (@Sendable () -> Void)?
    }

    /// `clock` times the wait for the watch's Health id. `defaults` holds the Health workouts
    /// still to delete.
    public init(
        live: any LiveWorkout, device: SessionDevice, clock: any Clock<Duration> = ContinuousClock(),
        defaults: UserDefaults = .standard
    ) {
        self.live = live
        self.device = device
        self.clock = clock
        self.defaults = defaults
        let (messages, outbox) = AsyncStream.makeStream(of: Outgoing.self)
        self.outbox = outbox
        Task {
            for await message in messages {
                await live.send(message.data)
                message.sent?()
            }
        }
    }

    /// Reads messages from the other device until the channel closes. Run it once, for the
    /// life of the app.
    public func run() async {
        for await data in live.incoming {
            do {
                await handle(try SessionMessage(data: data))
            } catch {
                Self.logger.notice("Dropped a session message: \(String(describing: error), privacy: .public)")
            }
        }
    }

    public var ownedID: UUID? {
        owned?.workout.id
    }

    /// Takes a running workout as this device's own, marks it so, and tells the other device.
    public func own(_ workout: Workout, in context: ModelContext, library: ExerciseLibrary = .bundled) {
        if workout.startedOn == nil {
            workout.startedOn = device
            try? context.save()
        }
        owned = Owned(workout: workout, context: context, library: library)
        mirrored = nil
        publish()
    }

    /// Sends the owned workout as it stands. Call it after every local change.
    public func publish() {
        guard let owned else { return }
        post(.snapshot(SessionSnapshot(owned.workout, library: owned.library)))
        if owned.workout.endedAt != nil {
            ending = Ending(
                workoutID: owned.workout.id, context: owned.context, expectsWatchReply: live.isMirroring)
            self.owned = nil
        }
    }

    /// The owned workout was thrown away: lets go of it and tells the other device.
    public func discarded() {
        guard let id = owned?.workout.id else { return }
        owned = nil
        post(.ended(workoutID: id, healthWorkoutID: nil))
    }

    /// Asks the owner to do something, and shows the likely result straight away. The owner's
    /// next snapshot replaces the guess.
    public func send(_ command: SessionCommand) {
        guard let snapshot = mirrored else { return }
        mirrored = snapshot.applying(command)
        post(.command(command, workoutID: snapshot.workoutID))
    }

    /// Asks the other device what it's running, e.g. after the iPhone woke the watch app.
    public func requestSnapshot() {
        post(.requestSnapshot)
    }

    /// Stops showing the other device's session, once its summary has been seen.
    public func dismissMirrored() {
        mirrored = nil
    }

    /// The watch's heart rate, for the iPhone to show.
    public func sendHeartRate(_ bpm: Double, at date: Date = .now) {
        post(.heartRate(bpm: bpm, at: date))
    }

    /// Saves a finished workout to Health, leaving exactly one Health workout linked to it.
    ///
    /// While the watch is recording, it saves the workout itself, with heart rate, and sends back
    /// its Health id. If it was recording this workout, this waits up to `timeout` for that id
    /// and adopts it. A `nil` from the watch ends the wait at once, and so does the timeout;
    /// either way the iPhone saves its own. If the watch's id still arrives later, the iPhone's
    /// Health workout is deleted and the watch's adopted. A call made while another is saving the
    /// same workout joins it.
    public func saveToHealth(
        _ workout: Workout, with health: any HealthService, waitingForWatch timeout: Duration = .seconds(5)
    ) async throws {
        guard health.isAvailable, workout.healthKitWorkoutID == nil else { return }
        let ending = ending(for: workout)
        if let saving = ending.saving { return try await saving.value }
        ending.health = health
        let saving = Task { try await save(workout, to: health, ending: ending, timeout: timeout) }
        ending.saving = saving
        defer { ending.saving = nil }
        try await saving.value
    }

    private func save(
        _ workout: Workout, to health: any HealthService, ending: Ending, timeout: Duration
    ) async throws {
        if let context = ending.context { await retryPendingDeletes(with: health, in: context) }
        if ending.expectsWatchReply { await ending.awaitReply(timeout: timeout, clock: clock) }
        guard workout.healthKitWorkoutID == nil, let record = HealthWorkoutRecord(workout) else { return }
        try await health.requestAccess(.workouts)
        let id = try await health.save(record)
        ending.phoneSaved = id
        // The watch's id may have landed while this was saving.
        if workout.healthKitWorkoutID == nil {
            workout.healthKitWorkoutID = id
            try? workout.modelContext?.save()
        }
        await reconcile(ending)
    }

    private func ending(for workout: Workout) -> Ending {
        if let ending, ending.workoutID == workout.id { return ending }
        let ending = Ending(workoutID: workout.id, context: workout.modelContext, expectsWatchReply: live.isMirroring)
        self.ending = ending
        return ending
    }

    /// The watch saved the workout to Health (or ended it without saving): tells the iPhone, so
    /// it keeps the Health id and doesn't save a second workout. Returns once the message has
    /// gone, so the sender can end its session after.
    public func ended(workoutID: UUID, healthWorkoutID: UUID?) async {
        guard let data = try? SessionMessage.ended(workoutID: workoutID, healthWorkoutID: healthWorkoutID).encoded()
        else { return }
        await withCheckedContinuation { continuation in
            let result = outbox.yield(Outgoing(data: data, sent: { continuation.resume() }))
            if case .enqueued = result { return }
            continuation.resume()
        }
    }

    func handle(_ message: SessionMessage) async {
        switch message {
        case .snapshot(let snapshot):
            guard snapshot.workoutID != ownedID else { return }
            mirrored = snapshot
        case .command(let command, let workoutID):
            guard let owned, owned.workout.id == workoutID else { return }
            let outcome = SessionMirror.apply(command, to: owned.workout, in: owned.context)
            onCommand?(command, outcome)
            if outcome == .discarded {
                discarded()
            } else {
                publish()
            }
        case .heartRate(let bpm, _):
            remoteHeartRate = bpm
        case .ended(let workoutID, let healthWorkoutID):
            await peerEnded(workoutID, healthWorkoutID)
        case .requestSnapshot:
            publish()
        }
    }

    private func peerEnded(_ workoutID: UUID, _ healthWorkoutID: UUID?) async {
        if mirrored?.workoutID == workoutID {
            // Finished sessions stay up for their summary; a discarded one just goes.
            if mirrored?.isFinished != true { mirrored = nil }
            return
        }
        guard let ending, ending.workoutID == workoutID else { return }
        ending.reply = healthWorkoutID.map(WatchReply.healthWorkout) ?? .nothingSaved
        ending.resumeWaiter()
        await reconcile(ending)
        if let health = ending.health, let context = ending.context {
            await retryPendingDeletes(with: health, in: context)
        }
    }

    /// Links the workout to the watch's Health workout, and deletes the iPhone's own if it saved
    /// one first.
    private func reconcile(_ ending: Ending) async {
        guard case .healthWorkout(let watchID)? = ending.reply, let context = ending.context else { return }
        let phoneSaved = ending.phoneSaved.flatMap { $0 == watchID ? nil : $0 }
        let entry = PendingDelete(workoutID: ending.workoutID, keep: watchID, remove: phoneSaved)
        // Written before anything changes, so a kill from here on is finished by the next pass.
        if !pending.contains(entry) { pending.append(entry) }
        ending.phoneSaved = nil
        await resolve(entry, with: ending.health, in: context)
    }

    /// Finishes any Health deletes an earlier pass left undone. Call it at launch, with the
    /// store the workouts live in.
    public func retryPendingDeletes(with health: any HealthService, in context: ModelContext) async {
        for entry in pending {
            await resolve(entry, with: health, in: context)
        }
    }

    /// Makes the workout point at `entry.keep`, then deletes what `entry` says to. The entry stays
    /// until every delete has gone through. A workout deleted from History in the meantime leaves
    /// nothing for the watch's Health workout to belong to, so that goes too.
    private func resolve(_ entry: PendingDelete, with health: (any HealthService)?, in context: ModelContext) async {
        let workoutID = entry.workoutID
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })
        var doomed = [UUID]()
        if let workout = try? context.fetch(descriptor).first {
            let current = workout.healthKitWorkoutID
            guard current == nil || current == entry.keep || current == entry.remove else {
                pending.removeAll { $0 == entry }
                return
            }
            if current != entry.keep {
                workout.healthKitWorkoutID = entry.keep
                try? context.save()
            }
        } else {
            doomed.append(entry.keep)
        }
        doomed.append(contentsOf: entry.remove.map { [$0] } ?? [])
        if !doomed.isEmpty {
            guard let health else { return }
            for id in doomed {
                do {
                    try await health.deleteWorkout(id: id)
                } catch {
                    Self.logger.notice(
                        "Couldn't delete a Health workout: \(String(describing: error), privacy: .public)")
                    return
                }
            }
        }
        pending.removeAll { $0 == entry }
    }

    private func post(_ message: SessionMessage) {
        guard let data = try? message.encoded() else { return }
        outbox.yield(Outgoing(data: data))
    }
}
