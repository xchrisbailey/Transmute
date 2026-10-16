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

    private var ending: Ending?

    private let clock: any Clock<Duration>
    private let pending: PendingHealthDeletes

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
        self.pending = PendingHealthDeletes(defaults: defaults)
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

    /// The `UserDefaults` keys the link keeps Health deletes in, for delete-all to clear.
    public nonisolated static let defaultsKeys = PendingHealthDeletes.keys

    public var ownedID: UUID? {
        owned?.workout.id
    }

    /// Takes a running workout as this device's own, marks it so, and tells the other device.
    public func own(_ workout: Workout, in context: ModelContext, library: ExerciseLibrary = .bundled) {
        if workout.claim(for: device) {
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
    /// gone, so the sender can end its session after, or after `timeout` on the clock if the
    /// channel is stuck: the watch ends its session either way.
    public func ended(workoutID: UUID, healthWorkoutID: UUID?, timeout: Duration = .seconds(3)) async {
        guard let data = try? SessionMessage.ended(workoutID: workoutID, healthWorkoutID: healthWorkoutID).encoded()
        else { return }
        let (sent, sentSignal) = AsyncStream.makeStream(of: Void.self)
        let result = outbox.yield(Outgoing(data: data, sent: { sentSignal.finish() }))
        guard case .enqueued = result else { return }
        let clock = clock
        await withTaskGroup(of: Void.self) { group in
            group.addTask { for await _ in sent {} }
            group.addTask { try? await clock.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
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
        let entry = PendingHealthDeletes.Entry(
            workoutID: ending.workoutID, watchHealthID: watchID, phoneHealthID: phoneSaved)
        // Written before anything changes, so a kill from here on is finished by the next pass.
        pending.add(entry)
        ending.phoneSaved = nil
        await resolve(entry, with: ending.health, in: context)
    }

    /// Finishes any Health deletes an earlier pass left undone. Call it at launch, with the
    /// store the workouts live in.
    public func retryPendingDeletes(with health: any HealthService, in context: ModelContext) async {
        for entry in pending.entries {
            await resolve(entry, with: health, in: context)
        }
    }

    /// Makes the workout point at `entry.watchHealthID`, then deletes what `entry` says to, the iPhone's own
    /// copy first. If a delete fails the entry stays, holding only the ids still to delete.
    ///
    /// A workout that isn't in `context` is gone for one of two reasons. If the person deleted it in
    /// History, nothing is left for the watch's Health workout to belong to, so that goes too. If it
    /// isn't known to be deleted, `context` may simply not be the store it lives in, so nothing is
    /// deleted and the entry waits.
    private func resolve(
        _ entry: PendingHealthDeletes.Entry, with health: (any HealthService)?, in context: ModelContext
    ) async {
        let workoutID = entry.workoutID
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })
        var doomed = [UUID]()
        var keepsRemain = true
        if let workout = try? context.fetch(descriptor).first {
            let current = workout.healthKitWorkoutID
            // With `watchHealthID` already dealt with, the iPhone's copy is deletable whatever the workout links to.
            guard
                entry.watchHealthID == nil || current == nil || current == entry.watchHealthID
                    || current == entry.phoneHealthID
            else {
                pending.remove(entry)
                return
            }
            if let watchHealthID = entry.watchHealthID, current != watchHealthID {
                workout.healthKitWorkoutID = watchHealthID
                try? context.save()
            }
            doomed = entry.phoneHealthID.map { [$0] } ?? []
        } else {
            guard pending.wasDeleted(workoutID) else { return }
            doomed = [entry.phoneHealthID, entry.watchHealthID].compactMap { $0 }
            keepsRemain = false
        }
        var failed = Set<UUID>()
        if !doomed.isEmpty {
            guard let health else { return }
            for id in doomed {
                do {
                    try await health.deleteWorkout(id: id)
                } catch {
                    Self.logger.notice(
                        "Couldn't delete a Health workout: \(String(describing: error), privacy: .public)")
                    failed.insert(id)
                }
            }
        }
        guard !failed.isEmpty else {
            pending.remove(entry)
            pending.forgetDeleted(workoutID)
            return
        }
        let watchHealthID = entry.watchHealthID.flatMap { keepsRemain || failed.contains($0) ? $0 : nil }
        pending.replace(
            entry,
            with: PendingHealthDeletes.Entry(
                workoutID: workoutID, watchHealthID: watchHealthID,
                phoneHealthID: entry.phoneHealthID.flatMap { failed.contains($0) ? $0 : nil }))
    }

    private func post(_ message: SessionMessage) {
        guard let data = try? message.encoded() else { return }
        outbox.yield(Outgoing(data: data))
    }
}
