import Foundation
import Observation

#if canImport(HealthKit)
    import HealthKit
#endif

/// A workout while it's happening: heart rate and energy from the watch, and a data channel
/// between the watch and the iPhone so either can log and both stay in sync (#15).
///
/// The watch always runs the Health workout session, whichever device started the workout.
/// `WatchLiveWorkout` is that end and `PhoneLiveWorkout` is the mirrored end on the iPhone. The
/// Mac, tests and previews use `UnavailableLiveWorkout`.
@MainActor
public protocol LiveWorkout: AnyObject, Observable {
    var state: LiveWorkoutState { get }

    /// The latest heart rate in beats per minute.
    var heartRate: Double? { get }

    /// The average heart rate so far in beats per minute.
    var averageHeartRate: Double? { get }

    /// Active energy burned so far in kilocalories.
    var activeEnergyKcal: Double? { get }

    /// Whether the other device is connected to the data channel.
    var isMirroring: Bool { get }

    /// Messages from the other device, in the order they arrived. One stream for the life of the
    /// object, so read it from a single task.
    var incoming: AsyncStream<Data> { get }

    /// Starts a workout. On the watch this starts the Health session; on the iPhone it launches
    /// the watch app, which starts one and mirrors it back.
    func start(activity: HealthActivity, at date: Date) async throws

    func pause()
    func resume()

    /// Sends a message to the other device. Best effort: it's dropped when the other device
    /// isn't connected.
    func send(_ data: Data) async

    /// Ends collection and saves the workout to Health with Transmute's workout id and title in
    /// its metadata. Returns the Health workout's id, or nil if nothing was saved.
    func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID?

    /// Ends the workout without saving it to Health.
    func discard() async
}

public enum LiveWorkoutState: String, Sendable, CaseIterable {
    /// No workout yet, or one that's been set up but hasn't started.
    case idle
    case running
    case paused
    /// The workout is over. Starting again begins a new one.
    case ended
}

/// Stands in for a live workout where there isn't one: the Mac, tests and previews.
@MainActor
@Observable
public final class UnavailableLiveWorkout: LiveWorkout {
    public let state = LiveWorkoutState.idle
    public let heartRate: Double? = nil
    public let averageHeartRate: Double? = nil
    public let activeEnergyKcal: Double? = nil
    public let isMirroring = false
    /// Never yields: the stream is already finished.
    public let incoming: AsyncStream<Data>

    public init() {
        incoming = AsyncStream { $0.finish() }
    }

    public func start(activity: HealthActivity, at date: Date) async throws {
        throw HealthServiceError.unavailable
    }

    public func pause() {}
    public func resume() {}
    public func send(_ data: Data) async {}
    public func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID? { nil }
    public func discard() async {}
}

#if canImport(HealthKit)
    extension LiveWorkoutState {
        /// A prepared session hasn't started, and a stopped one can't start again, so they count
        /// as idle and ended.
        init(_ state: HKWorkoutSessionState) {
            switch state {
            case .notStarted, .prepared: self = .idle
            case .running: self = .running
            case .paused: self = .paused
            case .stopped, .ended: self = .ended
            @unknown default: self = .idle
            }
        }
    }

    extension HealthWorkoutRecord {
        /// What marks a Health workout as Transmute's: our workout id, and the title as its name.
        static func metadata(workoutID: UUID, title: String) -> [String: Any] {
            [workoutIDKey: workoutID.uuidString, HKMetadataKeyWorkoutBrandName: title]
        }
    }
#endif
