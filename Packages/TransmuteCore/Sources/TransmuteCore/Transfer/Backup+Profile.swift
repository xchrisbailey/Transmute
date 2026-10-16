import Foundation

/// The profile and its settings.
///
/// Every key is optional, so a backup written before a setting existed still reads and the
/// profile keeps its default.
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
        for setting in Self.settings { setting.read(profile, &self) }
        bodyweights = (profile.bodyweights ?? []).map(BodyweightBackup.init).sorted {
            ($0.date, $0.kg) < ($1.date, $1.kg)
        }
    }

    /// Writes everything but the bodyweights, which the restore merges one by one.
    func apply(to profile: Profile) {
        for setting in Self.settings { setting.write(self, profile) }
    }

    /// Where each setting lives on the profile. Adding one is a property above and a line here.
    private static var settings: [Setting] {
        [
            Setting(\.id, \.id),
            Setting(\.createdAt, \.createdAt),
            Setting(\.heightCm, optional: \.heightCm),
            Setting(\.birthYear, optional: \.birthYear),
            Setting(\.sex, optional: \.sexRaw),
            Setting(\.experience, \.experienceRaw),
            Setting(\.sports, \.sports),
            Setting(\.goalText, \.goalText),
            Setting(\.goalTags, \.goalTagsRaw),
            Setting(\.schedule, \.schedule),
            Setting(\.equipment, \.equipmentRaw),
            Setting(\.limitations, \.limitations),
            Setting(\.limitationAreas, \.limitationAreasRaw),
            Setting(\.progression, \.progression),
            Setting(\.knownLifts, \.knownLifts),
            Setting(\.barbellKg, \.barbellKg),
            Setting(\.plates, \.plates),
            Setting(\.unitSystem, optional: \.unitSystemRaw),
            Setting(\.weightUnit, optional: \.weightUnitRaw),
            Setting(\.heightUnit, optional: \.heightUnitRaw),
            Setting(\.distanceUnit, optional: \.distanceUnitRaw),
            Setting(\.preferences, \.preferences),
        ]
    }

    private struct Setting {
        let read: (Profile, inout ProfileBackup) -> Void
        let write: (ProfileBackup, Profile) -> Void

        /// A setting the profile always has; a backup without it leaves the profile's default.
        init<Value>(
            _ backup: WritableKeyPath<ProfileBackup, Value?>, _ profile: ReferenceWritableKeyPath<Profile, Value>
        ) {
            read = { $1[keyPath: backup] = $0[keyPath: profile] }
            write = { if let value = $0[keyPath: backup] { $1[keyPath: profile] = value } }
        }

        /// A setting that is `nil` on the profile until chosen; a backup without it clears it.
        init<Value>(
            _ backup: WritableKeyPath<ProfileBackup, Value?>,
            optional profile: ReferenceWritableKeyPath<Profile, Value?>
        ) {
            read = { $1[keyPath: backup] = $0[keyPath: profile] }
            write = { $1[keyPath: profile] = $0[keyPath: backup] }
        }
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
