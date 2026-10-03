#if os(watchOS)
    import Foundation
    import HealthKit
    import Observation
    import os

    /// The watch end of a live workout: runs the Health workout session, collects heart rate and
    /// energy, mirrors the session to the iPhone and saves the workout to Health on finish.
    @MainActor
    @Observable
    public final class WatchLiveWorkout: NSObject, LiveWorkout {
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
        private var builder: HKLiveWorkoutBuilder?

        private nonisolated static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "health")

        public override init() {
            (incoming, inbox) = AsyncStream.makeStream(of: Data.self)
            super.init()
        }

        // MARK: Starting

        /// Starts an indoor session for the activity. Does nothing if a workout is already going.
        public func start(activity: HealthActivity, at date: Date) async throws {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activity.workoutActivityType
            configuration.locationType = .indoor
            try await begin(configuration, at: date)
        }

        /// Starts the session the iPhone asked for with `startWatchApp(toHandle:)`. Call it from
        /// the app delegate's `handle(_:)`. Does nothing if a workout is already going.
        public func start(with configuration: HKWorkoutConfiguration) async throws {
            try await begin(configuration, at: .now)
        }

        /// Picks a session back up after the app was relaunched or crashed mid-workout. Returns
        /// whether there was one.
        @discardableResult
        public func recover() async -> Bool {
            guard session == nil, HKHealthStore.isHealthDataAvailable() else { return false }
            do {
                guard let recovered = try await store.recoverActiveWorkoutSession(), session == nil else {
                    return false
                }
                let builder = recovered.associatedWorkoutBuilder()
                if builder.dataSource == nil {
                    builder.dataSource = HKLiveWorkoutDataSource(
                        healthStore: store, workoutConfiguration: recovered.workoutConfiguration)
                }
                adopt(recovered, builder)
                state = LiveWorkoutState(recovered.state)
                refreshMetrics(from: builder)
                await startMirroring()
                return true
            } catch {
                Self.logger.error(
                    "Couldn't recover the workout session: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }

        /// Connects the session to the iPhone. Called on start and recover; call it again to
        /// reconnect after `isMirroring` went false. Failing is fine: the workout carries on
        /// unmirrored.
        public func startMirroring() async {
            guard let session, !isMirroring else { return }
            do {
                try await session.startMirroringToCompanionDevice()
                if session === self.session { isMirroring = true }
            } catch {
                Self.logger.notice("Workout isn't mirrored: \(error.localizedDescription, privacy: .public)")
            }
        }

        private func begin(_ configuration: HKWorkoutConfiguration, at date: Date) async throws {
            guard HKHealthStore.isHealthDataAvailable() else { throw HealthServiceError.unavailable }
            guard session == nil else { return }
            do {
                let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
                adopt(session, builder)
                session.startActivity(with: date)
                try await builder.beginCollection(at: date)
            } catch {
                if let session {
                    session.end()
                    release()
                    state = .idle
                }
                throw Self.mapped(error)
            }
            await startMirroring()
        }

        private func adopt(_ session: HKWorkoutSession, _ builder: HKLiveWorkoutBuilder) {
            heartRate = nil
            averageHeartRate = nil
            activeEnergyKcal = nil
            isMirroring = false
            self.session = session
            self.builder = builder
            session.delegate = self
            builder.delegate = self
        }

        /// Lets go of the session. Its late delegate calls are ignored from here on.
        private func release() {
            session?.delegate = nil
            builder?.delegate = nil
            session = nil
            builder = nil
            isMirroring = false
        }

        // MARK: Running

        public func pause() {
            session?.pause()
        }

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

        // MARK: Ending

        public func finish(workoutID: UUID, title: String, at date: Date) async throws -> UUID? {
            guard let session, let builder else { return nil }
            defer {
                if session === self.session {
                    release()
                    state = .ended
                }
            }
            do {
                try await builder.addMetadata(HealthWorkoutRecord.metadata(workoutID: workoutID, title: title))
                session.end()
                try await builder.endCollection(at: date)
                let workout = try await builder.finishWorkout()
                refreshMetrics(from: builder)
                return workout?.uuid
            } catch {
                // Ending twice is harmless, and the watch mustn't be left in a session.
                session.end()
                builder.discardWorkout()
                throw Self.mapped(error)
            }
        }

        public func discard() async {
            guard let session, let builder else { return }
            session.end()
            builder.discardWorkout()
            if session === self.session {
                release()
                state = .ended
            }
        }

        private static func mapped(_ error: any Error) -> any Error {
            if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                return HealthServiceError.notAuthorized
            }
            return error
        }

        // MARK: Delegate updates

        private func syncState(of session: HKWorkoutSession) {
            guard session === self.session else { return }
            state = LiveWorkoutState(session.state)
        }

        private func disconnected(_ session: HKWorkoutSession) {
            guard session === self.session else { return }
            isMirroring = false
        }

        private func refreshMetrics(from builder: HKLiveWorkoutBuilder) {
            guard builder === self.builder else { return }
            let heart = builder.statistics(for: HKQuantityType(.heartRate))
            let energy = builder.statistics(for: HKQuantityType(.activeEnergyBurned))
            let bpm = HKUnit.count().unitDivided(by: .minute())
            heartRate = heart?.mostRecentQuantity()?.doubleValue(for: bpm)
            averageHeartRate = heart?.averageQuantity()?.doubleValue(for: bpm)
            activeEnergyKcal = energy?.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
    }

    // Health calls its delegates on its own queues. Everything hops to the main actor and reads
    // the latest value there, so the order the hops land in doesn't matter.
    extension WatchLiveWorkout: HKWorkoutSessionDelegate {
        public nonisolated func workoutSession(
            _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
            from fromState: HKWorkoutSessionState, date: Date
        ) {
            Task { @MainActor in self.syncState(of: workoutSession) }
        }

        public nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
            Self.logger.error("Workout session failed: \(error.localizedDescription, privacy: .public)")
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

    extension WatchLiveWorkout: HKLiveWorkoutBuilderDelegate {
        public nonisolated func workoutBuilder(
            _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
        ) {
            Task { @MainActor in self.refreshMetrics(from: workoutBuilder) }
        }

        public nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    }
#endif
