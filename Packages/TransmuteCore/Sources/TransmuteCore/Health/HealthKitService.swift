#if os(iOS) || os(watchOS)
    import Foundation
    import HealthKit
    import OSLog

    /// `HealthService` over HealthKit, for iPhone and Apple Watch.
    public final class HealthKitService: HealthService {
        private let store = HKHealthStore()
        private let calendar = Calendar(identifier: .gregorian)

        public init() {}

        public var isAvailable: Bool {
            HKHealthStore.isHealthDataAvailable()
        }

        // MARK: Access

        public func requestAccess(_ scope: HealthAccessScope) async throws {
            guard isAvailable else { return }
            let (share, read) = Self.types(for: scope)
            try await store.requestAuthorization(toShare: share, read: read)
        }

        static func types(for scope: HealthAccessScope) -> (share: Set<HKSampleType>, read: Set<HKObjectType>) {
            let bodyMass = HKQuantityType(.bodyMass)
            switch scope {
            case .profile:
                return (
                    [bodyMass],
                    [
                        bodyMass, HKQuantityType(.height), HKCharacteristicType(.dateOfBirth),
                        HKCharacteristicType(.biologicalSex),
                    ]
                )
            case .trainingLoad:
                return ([], [HKObjectType.workoutType(), HKQuantityType(.restingHeartRate), HKQuantityType(.vo2Max)])
            case .workouts:
                return (
                    [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)],
                    [HKObjectType.workoutType(), HKQuantityType(.heartRate)]
                )
            }
        }

        // MARK: Reading

        public func bodyMetrics() async -> HealthBodyMetrics {
            var metrics = HealthBodyMetrics()
            metrics.heightCm = await latest(.height, unit: .meterUnit(with: .centi))
            metrics.weightKg = await latest(.bodyMass, unit: .gramUnit(with: .kilo))
            metrics.birthYear = (try? store.dateOfBirthComponents())?.year
            switch (try? store.biologicalSex())?.biologicalSex {
            case .female: metrics.sex = .female
            case .male: metrics.sex = .male
            case .other: metrics.sex = .other
            default: break
            }
            return metrics
        }

        public func bodyweights(since date: Date) async -> [HealthBodyweight] {
            let samples = await quantitySamples(.bodyMass, since: date)
            return samples.map { sample in
                HealthBodyweight(
                    id: sample.uuid, date: sample.endDate, kg: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                    isFromTransmute: Self.isFromTransmute(sample))
            }
        }

        public func restingHeartRate() async -> Double? {
            await latest(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        }

        public func vo2Max() async -> Double? {
            let unit = HKUnit.literUnit(with: .milli).unitDivided(
                by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
            return await latest(.vo2Max, unit: unit)
        }

        public func otherWorkouts(in interval: DateInterval) async -> [OtherWorkout] {
            let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)], sortDescriptors: [SortDescriptor(\.startDate)])
            let workouts = (try? await descriptor.result(for: store)) ?? []
            return workouts.filter { !Self.isFromTransmute($0) }.map { workout in
                let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()
                let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()
                return OtherWorkout(
                    id: workout.uuid, activity: workout.workoutActivityType.name, start: workout.startDate,
                    end: workout.endDate, energyKcal: energy?.doubleValue(for: .kilocalorie()),
                    averageHeartRate: heartRate?.doubleValue(for: .count().unitDivided(by: .minute())))
            }
        }

        /// Written by this app, or carrying our workout id from another Transmute device.
        static func isFromTransmute(_ sample: HKSample) -> Bool {
            sample.sourceRevision.source.bundleIdentifier.hasPrefix(Transmute.bundlePrefix)
                || sample.metadata?[HealthWorkoutRecord.workoutIDKey] != nil
        }

        private func latest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(identifier))],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
            return (try? await descriptor.result(for: store))?.first?.quantity.doubleValue(for: unit)
        }

        private func quantitySamples(_ identifier: HKQuantityTypeIdentifier, since date: Date) async
            -> [HKQuantitySample]
        {
            let predicate = HKQuery.predicateForSamples(withStart: date, end: nil)
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(identifier), predicate: predicate)],
                sortDescriptors: [SortDescriptor(\.endDate)])
            return (try? await descriptor.result(for: store)) ?? []
        }

        // MARK: Writing

        public func save(_ record: HealthWorkoutRecord) async throws -> UUID {
            guard isAvailable else { throw HealthServiceError.unavailable }
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = record.activity.workoutActivityType
            configuration.locationType = .indoor
            let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
            do {
                try await builder.beginCollection(at: record.start)
                var samples: [HKSample] = record.heartRate.map { sample in
                    HKQuantitySample(
                        type: HKQuantityType(.heartRate),
                        quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: sample.bpm),
                        start: sample.date, end: sample.date)
                }
                if let energy = record.energyKcal {
                    samples.append(
                        HKQuantitySample(
                            type: HKQuantityType(.activeEnergyBurned),
                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy), start: record.start,
                            end: record.end))
                }
                if !samples.isEmpty {
                    try await builder.addSamples(samples)
                }
                try await builder.addMetadata([
                    HealthWorkoutRecord.workoutIDKey: record.workoutID.uuidString,
                    HKMetadataKeyWorkoutBrandName: record.title,
                ])
                try await builder.endCollection(at: record.end)
                guard let workout = try await builder.finishWorkout() else { throw HealthServiceError.notAuthorized }
                return workout.uuid
            } catch let error as HKError where error.code == .errorAuthorizationDenied {
                throw HealthServiceError.notAuthorized
            }
        }

        public func saveBodyweight(kg: Double, at date: Date) async throws -> UUID {
            guard isAvailable else { throw HealthServiceError.unavailable }
            let sample = HKQuantitySample(
                type: HKQuantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                start: date, end: date)
            do {
                try await store.save(sample)
            } catch let error as HKError where error.code == .errorAuthorizationDenied {
                throw HealthServiceError.notAuthorized
            }
            return sample.uuid
        }

        public func deleteWorkout(id: UUID) async throws {
            guard isAvailable else { throw HealthServiceError.unavailable }
            let predicate = HKQuery.predicateForObjects(with: [id])
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)
            do {
                // Only Transmute's own workouts carry its id, so nothing from another app goes.
                for workout in try await descriptor.result(for: store)
                where workout.metadata?[HealthWorkoutRecord.workoutIDKey] != nil {
                    try await store.delete(workout)
                }
            } catch let error as HKError where error.code == .errorAuthorizationDenied {
                throw HealthServiceError.notAuthorized
            }
        }
    }

    extension HealthActivity {
        var workoutActivityType: HKWorkoutActivityType {
            switch self {
            case .traditionalStrength: .traditionalStrengthTraining
            case .functionalStrength: .functionalStrengthTraining
            case .highIntensityInterval: .highIntensityIntervalTraining
            case .running: .running
            case .cycling: .cycling
            case .rowing: .rowing
            case .flexibility: .flexibility
            case .mixed: .mixedCardio
            }
        }
    }

    extension HKWorkoutActivityType {
        /// A plain English name for prompts and the week view. Common sports are named; anything
        /// else is "other training".
        var name: String {
            switch self {
            case .tennis: "tennis"
            case .pickleball: "pickleball"
            case .badminton: "badminton"
            case .squash: "squash"
            case .tableTennis: "table tennis"
            case .running: "running"
            case .walking: "walking"
            case .hiking: "hiking"
            case .cycling: "cycling"
            case .swimming: "swimming"
            case .rowing: "rowing"
            case .soccer: "soccer"
            case .basketball: "basketball"
            case .climbing: "climbing"
            case .yoga: "yoga"
            case .traditionalStrengthTraining, .functionalStrengthTraining: "strength training"
            case .highIntensityIntervalTraining: "HIIT"
            case .golf: "golf"
            default: "other training"
            }
        }
    }
#endif
