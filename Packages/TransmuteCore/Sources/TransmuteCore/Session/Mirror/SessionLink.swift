import Foundation
import OSLog
import Observation  // swiftlint:disable:this sorted_imports
import SwiftData

/// Keeps a session in step between the iPhone and the watch (#15), over the live workout's
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

    /// The workout this device runs and saves, with where it lives.
    private struct Owned {
        let workout: Workout
        let context: ModelContext
        let library: ExerciseLibrary
    }

    private var owned: Owned?

    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "link")

    /// Messages go out one at a time, so a newer snapshot never lands before an older one.
    private let outbox: AsyncStream<Data>.Continuation

    public init(live: any LiveWorkout, device: SessionDevice) {
        self.live = live
        self.device = device
        let (messages, outbox) = AsyncStream.makeStream(of: Data.self)
        self.outbox = outbox
        Task {
            for await data in messages {
                await live.send(data)
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

    // MARK: Owning

    /// The id of the workout this device is running.
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
        if owned.workout.endedAt != nil { self.owned = nil }
    }

    /// The owned workout was thrown away: lets go of it and tells the other device.
    public func discarded() {
        guard let id = owned?.workout.id else { return }
        owned = nil
        post(.ended(workoutID: id, healthWorkoutID: nil))
    }

    // MARK: Mirroring

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

    // MARK: Health

    /// The watch's heart rate, for the iPhone to show.
    public func sendHeartRate(_ bpm: Double, at date: Date = .now) {
        post(.heartRate(bpm: bpm, at: date))
    }

    /// The watch saved the workout to Health (or ended it without saving): tells the iPhone, so
    /// it keeps the Health id and doesn't save a second workout.
    public func ended(workoutID: UUID, healthWorkoutID: UUID?) {
        post(.ended(workoutID: workoutID, healthWorkoutID: healthWorkoutID))
    }

    // MARK: Messages

    func handle(_ message: SessionMessage) async {
        switch message {
        case .snapshot(let snapshot):
            // A snapshot of the workout this device owns is an echo; the store is the truth.
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
            ended(workoutID, healthWorkoutID)
        case .requestSnapshot:
            publish()
        }
    }

    private func ended(_ workoutID: UUID, _ healthWorkoutID: UUID?) {
        if mirrored?.workoutID == workoutID {
            // Finished sessions stay up for their summary; a discarded one just goes.
            if mirrored?.isFinished != true { mirrored = nil }
            return
        }
        guard let healthWorkoutID else { return }
        // The watch saved this device's workout to Health. It may have ended already, so look
        // it up rather than relying on what's owned.
        guard let context = owned?.context ?? lastContext else { return }
        let descriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })
        guard let workout = try? context.fetch(descriptor).first, workout.healthKitWorkoutID == nil else { return }
        workout.healthKitWorkoutID = healthWorkoutID
        try? context.save()
    }

    /// The store of the last owned workout, kept so its Health id can arrive after it ends.
    private var lastContext: ModelContext?

    private func post(_ message: SessionMessage) {
        if let owned { lastContext = owned.context }
        guard let data = try? message.encoded() else { return }
        outbox.yield(data)
    }
}
