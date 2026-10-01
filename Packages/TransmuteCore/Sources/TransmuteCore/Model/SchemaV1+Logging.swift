import Foundation
import SwiftData

extension SchemaV1 {

    /// A logged session.
    @Model public final class Workout {
        public var id = UUID()
        public var title = ""
        public var startedAt = Date.now
        public var endedAt: Date?
        public var notes = ""
        /// The workout Transmute saved to Health, once saved.
        public var healthKitWorkoutID: UUID?
        public var planDay: PlanDay?
        /// When the running rest ends, so a relaunched app picks the timer back up (#11).
        public var restEndsAt: Date?
        /// How long that rest was set for, for the countdown ring.
        public var restSeconds: Double?

        @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.workout)
        public var exercises: [LoggedExercise]? = []

        public init(title: String, startedAt: Date = .now, planDay: PlanDay? = nil) {
            self.title = title
            self.startedAt = startedAt
            self.planDay = planDay
        }

        public var duration: TimeInterval? {
            endedAt.map { $0.timeIntervalSince(startedAt) }
        }

        public var orderedExercises: [LoggedExercise] {
            (exercises ?? []).sorted { $0.order < $1.order }
        }

        /// Total kilograms lifted in completed weight × reps sets.
        public var volumeKg: Double {
            orderedExercises.flatMap(\.orderedSets).filter(\.isCompleted).reduce(0) { total, set in
                total + (set.weightKg ?? 0) * Double(set.reps ?? 0)
            }
        }
    }

    @Model public final class LoggedExercise {
        public var exerciseID = ""
        public var order = 0
        public var notes = ""
        /// Passed over mid-session. Its sets stay unlogged.
        public var isSkipped = false
        /// The exercise this one stood in for, when it was substituted mid-session.
        public var substitutedFromID: String?
        public var workout: Workout?

        @Relationship(deleteRule: .cascade, inverse: \LoggedSet.exercise)
        public var sets: [LoggedSet]? = []

        public init(exerciseID: String, order: Int) {
            self.exerciseID = exerciseID
            self.order = order
        }

        public var orderedSets: [LoggedSet] {
            (sets ?? []).sorted { $0.order < $1.order }
        }
    }

    @Model public final class LoggedSet {
        public var order = 0
        public var weightKg: Double?
        public var reps: Int?
        public var seconds: Double?
        public var meters: Double?
        public var rpe: Double?
        public var rounds: Int?
        public var isWarmUp = false
        public var isCompleted = false
        public var completedAt: Date?
        public var notes = ""
        /// The planned rest after this set, which the rest timer starts with.
        public var restSeconds: Double?
        /// For intervals: rest between rounds of `seconds` work.
        public var intervalRestSeconds: Double?
        /// The person confirmed an unusually big jump is real, so record detection trusts it
        /// rather than asking again (#13).
        public var isRecordConfirmed = false
        public var exercise: LoggedExercise?

        @Relationship(deleteRule: .nullify, inverse: \PersonalRecord.set)
        public var records: [PersonalRecord]? = []

        public init(
            order: Int, weightKg: Double? = nil, reps: Int? = nil, seconds: Double? = nil, meters: Double? = nil,
            rpe: Double? = nil
        ) {
            self.order = order
            self.weightKg = weightKg
            self.reps = reps
            self.seconds = seconds
            self.meters = meters
            self.rpe = rpe
        }

        public func complete(at date: Date = .now) {
            isCompleted = true
            completedAt = date
        }
    }

    // MARK: - Records

    @Model public final class PersonalRecord {
        public var exerciseID = ""
        public var kindRaw = RecordKind.estimatedOneRepMax.rawValue
        /// Kilograms, reps, seconds or metres, depending on the kind.
        public var value = 0.0
        /// The rep count for a rep max, e.g. 5 for a 5RM.
        public var reps: Int?
        /// The distance for a best time.
        public var meters: Double?
        public var date = Date.now
        public var set: LoggedSet?

        public init(exerciseID: String, kind: RecordKind, value: Double, date: Date = .now, set: LoggedSet? = nil) {
            self.exerciseID = exerciseID
            self.kindRaw = kind.rawValue
            self.value = value
            self.date = date
            self.set = set
        }

        public var kind: RecordKind {
            get { RecordKind(rawValue: kindRaw) ?? .estimatedOneRepMax }
            set { kindRaw = newValue.rawValue }
        }
    }
}
