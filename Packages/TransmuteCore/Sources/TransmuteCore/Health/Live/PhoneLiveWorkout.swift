#if os(iOS)
    import Foundation
    import HealthKit
    import Observation
    import os

    /// The iPhone end of a live workout: the mirror of the session the watch is running.
    ///
    /// The watch has the sensors and saves the workout, so this end only follows the session's
    /// state and carries messages. A mirrored session has no workout builder, so heart rate and
    /// energy stay nil until the watch sends them over the data channel and they're passed to
    /// `update(heartRate:averageHeartRate:activeEnergyKcal:)`.
    @MainActor
    @Observable
    public final class PhoneLiveWorkout: NSObject, LiveWorkout {
        public private(set) var state = LiveWorkoutState.idle
        public private(set) var heartRate: Double?
        public private(set) var averageHeartRate: Double?
        public private(set) var activeEnergyKcal: Double?
        public private(set) var isMirroring = false
        public let incoming: AsyncStream<Data>

        /// Fed straight from the delegate's queue, so messages keep their order.
        private nonisolated let inbox: AsyncStream<Data>.Continuation
        private let store = HKHealthStore()
        private var session: HKWorkoutSession?

        private nonisolated static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "health")

        public override init() {
            (incoming, inbox) = AsyncStream.makeStream(of: Data.self)
            super.init()
        }

        /// Starts waiting for the watch to mirror a session. Call it as soon as the app launches,
        /// every launch: Health launches the app in the background when the watch starts one.
        public func listen() {
            guard HKHealthStore.isHealthDataAvailable() else { return }
            store.workoutSessionMirroringStartHandler = { [weak self] mirrored in
                guard let self else { return }
                // Set here, on Health's queue, so no message is missed before the hop lands.
                mirrored.delegate = self
                Task { @MainActor in self.adopt(mirrored) }
            }
        }

        /// Launches the watch app to start the workout there. The state changes once the watch
        /// mirrors its session back, so the date is the watch's to choose.
        public func start(activity: HealthActivity, at date: Date) async throws {
            guard HKHealthStore.isHealthDataAvailable() else { throw HealthServiceError.unavailable }
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activity.workoutActivityType
            configuration.locationType = .indoor
            do {
                try await store.startWatchApp(toHandle: configuration)
            } catch let error as HKError where error.code == .errorAuthorizationDenied {
                throw HealthServiceError.notAuthorized
            }
        }

        /// Pauses the watch's session through the mirror.
        public func pause() {
            session?.pause()
        }

        /// Resumes the watch's session through the mirror.
        public func resume() {
            session?.resume()
        }

        public func send(_ data: Data) async {
            guard let session else { return }
            do {
                try await session.sendToRemoteWorkoutSession(data: data)
            } catch {
                Self.logger.debug("Workout message not sent: \(error.localizedDescription, privacy: .public)")
            }
        }

        /// Shows what the watch measured, once it arrives over the data channel.
        public func update(heartRate: Double?, averageHeartRate: Double?, activeEnergyKcal: Double?) {
            self.heartRate = heartRate
            self.averageHeartRate = averageHeartRate
            self.activeEnergyKcal = activeEnergyKcal
        }

        /// Always nil: the watch saves the workout. Tell it to finish with a message; the state
        /// becomes `.ended` when its session ends.
        public func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID? {
            nil
        }

        /// Does nothing: only the watch can end its session without leaving a workout half built.
        /// Tell it to discard with a message.
        public func discard() async {}

        private func adopt(_ mirrored: HKWorkoutSession) {
            session = mirrored
            heartRate = nil
            averageHeartRate = nil
            activeEnergyKcal = nil
            isMirroring = true
            state = LiveWorkoutState(mirrored.state)
        }

        private func syncState(of session: HKWorkoutSession) {
            guard session === self.session else { return }
            state = LiveWorkoutState(session.state)
            if state == .ended {
                self.session = nil
                isMirroring = false
            }
        }

        /// A disconnected mirror is no longer valid. The watch mirrors a new one when it reconnects.
        private func disconnected(_ session: HKWorkoutSession) {
            guard session === self.session else { return }
            self.session = nil
            isMirroring = false
        }
    }

    // Health calls its delegate on its own queue. State hops to the main actor and reads the
    // latest value there, so the order the hops land in doesn't matter.
    extension PhoneLiveWorkout: HKWorkoutSessionDelegate {
        public nonisolated func workoutSession(
            _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
            from fromState: HKWorkoutSessionState, date: Date
        ) {
            Task { @MainActor in self.syncState(of: workoutSession) }
        }

        public nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
            Self.logger.error("Mirrored workout session failed: \(error.localizedDescription, privacy: .public)")
            Task { @MainActor in self.syncState(of: workoutSession) }
        }

        public nonisolated func workoutSession(
            _ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]
        ) {
            for message in data {
                inbox.yield(message)
            }
        }

        public nonisolated func workoutSession(
            _ workoutSession: HKWorkoutSession, didDisconnectFromRemoteDeviceWithError error: (any Error)?
        ) {
            Task { @MainActor in self.disconnected(workoutSession) }
        }
    }
#endif
