import Foundation

/// The profile and its settings.
///
/// Every key is optional, so a backup written before a setting existed still reads and the
/// profile keeps its default. Adding a setting is one line in each of the three places below:
/// the property, `init(_:)` and `apply(to:)`.
struct ProfileBackup: Codable, Equatable {
    var id: UUID?
    var createdAt: Date?
    var heightCm: Double?
    var birthYear: Int?
    var sex: String?
    var experience: String?
    var sports: [String]?
    var goalText: String?
    var goalTags: [String]?
    var schedule: Schedule?
    var equipment: [String]?
    var limitations: String?
    var limitationAreas: [String]?
    var progression: ProgressionSettings?
    var knownLifts: [KnownLift]?
    var barbellKg: Double?
    var plates: PlateInventory?
    var unitSystem: String?
    var weightUnit: String?
    var heightUnit: String?
    var distanceUnit: String?
    var preferences: WorkoutPreferences?
    var bodyweights: [BodyweightBackup]?

    init(_ profile: Profile) {
        id = profile.id
        createdAt = profile.createdAt
        heightCm = profile.heightCm
        birthYear = profile.birthYear
        sex = profile.sexRaw
        experience = profile.experienceRaw
        sports = profile.sports
        goalText = profile.goalText
        goalTags = profile.goalTagsRaw
        schedule = profile.schedule
        equipment = profile.equipmentRaw
        limitations = profile.limitations
        limitationAreas = profile.limitationAreasRaw
        progression = profile.progression
        knownLifts = profile.knownLifts
        barbellKg = profile.barbellKg
        plates = profile.plates
        unitSystem = profile.unitSystemRaw
        weightUnit = profile.weightUnitRaw
        heightUnit = profile.heightUnitRaw
        distanceUnit = profile.distanceUnitRaw
        preferences = profile.preferences
        bodyweights = (profile.bodyweights ?? []).map(BodyweightBackup.init).sorted {
            ($0.date, $0.kg) < ($1.date, $1.kg)
        }
    }

    /// Writes everything but the bodyweights, which the restore merges one by one.
    func apply(to profile: Profile) {
        assign(id, to: &profile.id)
        assign(createdAt, to: &profile.createdAt)
        profile.heightCm = heightCm
        profile.birthYear = birthYear
        profile.sexRaw = sex
        assign(experience, to: &profile.experienceRaw)
        assign(sports, to: &profile.sports)
        assign(goalText, to: &profile.goalText)
        assign(goalTags, to: &profile.goalTagsRaw)
        assign(schedule, to: &profile.schedule)
        assign(equipment, to: &profile.equipmentRaw)
        assign(limitations, to: &profile.limitations)
        assign(limitationAreas, to: &profile.limitationAreasRaw)
        assign(progression, to: &profile.progression)
        assign(knownLifts, to: &profile.knownLifts)
        assign(barbellKg, to: &profile.barbellKg)
        assign(plates, to: &profile.plates)
        profile.unitSystemRaw = unitSystem
        profile.weightUnitRaw = weightUnit
        profile.heightUnitRaw = heightUnit
        profile.distanceUnitRaw = distanceUnit
        assign(preferences, to: &profile.preferences)
    }

    /// Leaves the model's default in place when the backup has no value.
    private func assign<Value>(_ value: Value?, to target: inout Value) {
        if let value { target = value }
    }
}

struct BodyweightBackup: Codable, Equatable {
    var date: Date
    var kg: Double
    var healthKitSampleID: UUID?

    init(_ entry: BodyweightEntry) {
        date = entry.date
        kg = entry.kg
        healthKitSampleID = entry.healthKitSampleID
    }

    func model() -> BodyweightEntry {
        BodyweightEntry(date: date, kg: kg, healthKitSampleID: healthKitSampleID)
    }

    /// Whether this is the same weigh-in: the same Health sample, or the same reading at the
    /// same moment.
    func matches(_ other: BodyweightBackup) -> Bool {
        if let healthKitSampleID, healthKitSampleID == other.healthKitSampleID { return true }
        return date == other.date && kg == other.kg
    }
}

struct CustomExerciseBackup: Codable, Equatable {
    var exerciseID: String
    var createdAt: Date
    var name: String
    var aliases: [String]
    var category: String
    var pattern: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var equipment: [String]
    var tracking: String
    var isUnilateral: Bool
    var difficulty: String
    var cues: [String]
    var sportTags: [String]

    init(_ exercise: CustomExercise) {
        exerciseID = exercise.exerciseID
        createdAt = exercise.createdAt
        name = exercise.name
        aliases = exercise.aliases
        category = exercise.categoryRaw
        pattern = exercise.patternRaw
        primaryMuscles = exercise.primaryMusclesRaw
        secondaryMuscles = exercise.secondaryMusclesRaw
        equipment = exercise.equipmentRaw
        tracking = exercise.trackingRaw
        isUnilateral = exercise.isUnilateral
        difficulty = exercise.difficultyRaw
        cues = exercise.cues
        sportTags = exercise.sportTags
    }

    func model() -> CustomExercise {
        let exercise = CustomExercise(name: name, category: .strength, pattern: .isolation, tracking: .weightReps)
        exercise.exerciseID = exerciseID
        exercise.createdAt = createdAt
        exercise.aliases = aliases
        exercise.categoryRaw = category
        exercise.patternRaw = pattern
        exercise.primaryMusclesRaw = primaryMuscles
        exercise.secondaryMusclesRaw = secondaryMuscles
        exercise.equipmentRaw = equipment
        exercise.trackingRaw = tracking
        exercise.isUnilateral = isUnilateral
        exercise.difficultyRaw = difficulty
        exercise.cues = cues
        exercise.sportTags = sportTags
        return exercise
    }
}
