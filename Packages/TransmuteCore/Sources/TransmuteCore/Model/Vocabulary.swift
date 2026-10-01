/// The fixed vocabularies models and the exercise library share. Models store these as raw
/// strings so CloudKit and future schema versions can read values they don't know yet.

public enum ExperienceLevel: String, Codable, CaseIterable, Sendable {
    /// Never trained, or not for a long time.
    case beginner
    /// Trains regularly and knows the main lifts.
    case intermediate
    /// Years of structured training.
    case advanced
}

public enum Sex: String, Codable, CaseIterable, Sendable {
    case female, male, other
}

/// Structured tags the AI and progression read alongside the goal in plain words.
public enum GoalTag: String, Codable, CaseIterable, Sendable {
    case strength, hypertrophy, power, speed, agility, endurance, conditioning
    case weightLoss, mobility, sportPerformance, generalFitness, injuryResilience
}

public enum Equipment: String, Codable, CaseIterable, Sendable {
    case barbell, dumbbell, kettlebell, machine, cable, bodyweight, band, bench, rack
    case pullUpBar, medicineBall, box, sled, ladder, cones, rower, bike, treadmill, jumpRope, trapBar, landmine
    case plate, hurdle, sandbag, climbingRope, dipStation, slider, stabilityBall, foamRoller, abWheel, pool, flexBar
}

/// How a set is measured, which decides the fields a set row shows.
public enum TrackingType: String, Codable, CaseIterable, Sendable {
    /// Load and reps, e.g. a back squat.
    case weightReps
    /// Reps only, e.g. push-ups.
    case reps
    /// Time only, e.g. a plank.
    case time
    /// Distance and time, e.g. a 20 m sprint or a 2 km row.
    case distanceTime
    /// Work and rest for a number of rounds, e.g. 8 × 20 s on, 10 s off.
    case intervals
}

public enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case strength, power, speedAgility, conditioning, mobility
}

public enum MovementPattern: String, Codable, CaseIterable, Sendable {
    case squat, hinge, lunge, horizontalPush, verticalPush, horizontalPull, verticalPull
    case carry, rotation, antiRotation, core, jump, `throw`, sprint, changeOfDirection
    case locomotion, cyclical, mobility, isolation
}

public enum Muscle: String, Codable, CaseIterable, Sendable {
    case quads, hamstrings, glutes, adductors, abductors, calves, hipFlexors
    case chest, frontDelts, sideDelts, rearDelts, triceps, biceps, forearms
    case lats, upperBack, traps, lowerBack, abs, obliques, rotatorCuff, neck, fullBody, cardio
}

public enum RecordKind: String, Codable, CaseIterable, Sendable {
    /// Estimated one-rep max from a weight × reps set.
    case estimatedOneRepMax
    /// Heaviest load for a given number of reps (the record's `reps`).
    case repMax
    /// Most reps in a set.
    case maxReps
    /// Fastest time for a given distance (the record's `meters`).
    case bestTime
    /// Longest hold or effort, for time-tracked work.
    case longestTime
    /// Furthest distance in one set.
    case longestDistance
}

/// ISO weekday: 1 is Monday, 7 is Sunday.
public typealias Weekday = Int

/// Something fixed in the week the plan works around, like a match or practice.
public struct Commitment: Codable, Hashable, Sendable {
    public var weekday: Weekday
    public var label: String
    /// How hard it is, so the plan can keep heavy days away from it.
    public var intensity: Intensity

    public enum Intensity: String, Codable, Sendable {
        case light, moderate, hard
    }

    public init(weekday: Weekday, label: String, intensity: Intensity = .moderate) {
        self.weekday = weekday
        self.label = label
        self.intensity = intensity
    }
}

public struct Schedule: Codable, Hashable, Sendable {
    public var daysPerWeek: Int
    public var preferredWeekdays: [Weekday]
    public var sessionMinutes: Int
    public var weeks: Int
    public var commitments: [Commitment]

    public init(
        daysPerWeek: Int = 3, preferredWeekdays: [Weekday] = [], sessionMinutes: Int = 60, weeks: Int = 4,
        commitments: [Commitment] = []
    ) {
        self.daysPerWeek = daysPerWeek
        self.preferredWeekdays = preferredWeekdays
        self.sessionMinutes = sessionMinutes
        self.weeks = weeks
        self.commitments = commitments
    }
}
