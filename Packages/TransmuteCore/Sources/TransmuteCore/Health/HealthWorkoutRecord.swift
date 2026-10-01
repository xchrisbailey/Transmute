import Foundation

/// The kind of session a Transmute workout was, as Health files it.
public enum HealthActivity: String, Sendable, CaseIterable {
    case traditionalStrength, functionalStrength, highIntensityInterval, running, cycling, rowing, flexibility, mixed

    /// Picks the activity from what was actually done. Lifting days are strength; days that
    /// are mostly power, speed and agility are functional strength; mostly conditioning is
    /// HIIT, unless it's a single steady machine; mostly mobility is flexibility.
    public static func infer(from exercises: [LibraryExercise]) -> HealthActivity {
        guard !exercises.isEmpty else { return .traditionalStrength }
        var counts: [ExerciseCategory: Int] = [:]
        for exercise in exercises {
            counts[exercise.category, default: 0] += 1
        }
        let top = counts.max { ($0.value, $0.key.priority) < ($1.value, $1.key.priority) }!.key
        switch top {
        case .strength:
            return .traditionalStrength
        case .power, .speedAgility:
            return .functionalStrength
        case .mobility:
            return .flexibility
        case .conditioning:
            let equipment = Set(exercises.filter { $0.category == .conditioning }.flatMap(\.allEquipment))
            if exercises.count == 1 || equipment.count == 1 {
                if equipment.contains(.treadmill) || exercises.contains(where: { $0.pattern == .sprint }) {
                    return .running
                }
                if equipment.contains(.bike) { return .cycling }
                if equipment.contains(.rower) { return .rowing }
            }
            return .highIntensityInterval
        }
    }
}

extension ExerciseCategory {
    /// Breaks ties between equally common categories: the heavier kind of training wins.
    fileprivate var priority: Int {
        switch self {
        case .strength: 4
        case .power: 3
        case .speedAgility: 2
        case .conditioning: 1
        case .mobility: 0
        }
    }
}

/// A finished workout, ready to save to Health.
public struct HealthWorkoutRecord: Equatable, Sendable {
    /// The Transmute workout's id, stored as metadata so it can be recognised when reading back.
    public var workoutID: UUID
    public var title: String
    public var activity: HealthActivity
    public var start: Date
    public var end: Date
    public var energyKcal: Double?
    /// Heart rate samples in beats per minute, when the watch recorded them (#15).
    public var heartRate: [HeartRateSample]

    public init(
        workoutID: UUID, title: String, activity: HealthActivity, start: Date, end: Date, energyKcal: Double? = nil,
        heartRate: [HeartRateSample] = []
    ) {
        self.workoutID = workoutID
        self.title = title
        self.activity = activity
        self.start = start
        self.end = end
        self.energyKcal = energyKcal
        self.heartRate = heartRate
    }

    /// The record for a finished workout, with its activity inferred from the exercises.
    /// `nil` while the workout is still going.
    public init?(
        _ workout: Workout, library: ExerciseLibrary = .bundled, energyKcal: Double? = nil,
        heartRate: [HeartRateSample] = []
    ) {
        guard let end = workout.endedAt else { return nil }
        let exercises = workout.orderedExercises.compactMap { library.exercise(id: $0.exerciseID) }
        self.init(
            workoutID: workout.id, title: workout.title, activity: .infer(from: exercises), start: workout.startedAt,
            end: end, energyKcal: energyKcal, heartRate: heartRate)
    }

    /// Metadata key holding `workoutID` on the Health workout.
    public static let workoutIDKey = "TransmuteWorkoutID"
}

public struct HeartRateSample: Equatable, Sendable {
    public var date: Date
    public var bpm: Double

    public init(date: Date, bpm: Double) {
        self.date = date
        self.bpm = bpm
    }
}
