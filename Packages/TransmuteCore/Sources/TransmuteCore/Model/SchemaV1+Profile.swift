import Foundation
import SwiftData

extension SchemaV1 {

    @Model public final class Profile {
        public var id = UUID()
        public var createdAt = Date.now
        public var heightCm: Double?
        public var birthYear: Int?
        public var sexRaw: String?
        public var experienceRaw = ExperienceLevel.beginner.rawValue
        /// Optional; empty when the goal isn't about a sport.
        public var sports: [String] = []
        /// The goal in the user's own words.
        public var goalText = ""
        public var goalTagsRaw: [String] = []
        public var schedule = Schedule()
        public var equipmentRaw: [String] = []
        /// Injuries and limitations in plain words; plans treat them as constraints.
        public var limitations = ""
        /// Body areas the limitations name, picked as chips.
        public var limitationAreasRaw: [String] = []
        /// Lifts an experienced person entered, for starting loads.
        public var knownLifts: [KnownLift] = []
        /// The chosen bar's weight. A copy of `plates.barKg`, written whenever the profile is
        /// saved, for anything that only needs the bar; `plates` is the source of truth.
        public var barbellKg = 20.0
        /// Bars, plates, dumbbells and machine steps, for the plate calculator and for rounding
        /// loads (#21). Starts as the commercial-gym preset in the locale's unit.
        public var plates = PlateInventory.standard()
        /// `nil` follows the device locale.
        public var unitSystemRaw: String?

        @Relationship(deleteRule: .cascade, inverse: \BodyweightEntry.profile)
        public var bodyweights: [BodyweightEntry]? = []

        public init() {}

        public var sex: Sex? {
            get { sexRaw.flatMap(Sex.init(rawValue:)) }
            set { sexRaw = newValue?.rawValue }
        }

        public var experience: ExperienceLevel {
            get { ExperienceLevel(rawValue: experienceRaw) ?? .beginner }
            set { experienceRaw = newValue.rawValue }
        }

        public var goalTags: [GoalTag] {
            get { goalTagsRaw.compactMap(GoalTag.init(rawValue:)) }
            set { goalTagsRaw = newValue.map(\.rawValue) }
        }

        public var equipment: [Equipment] {
            get { equipmentRaw.compactMap(Equipment.init(rawValue:)) }
            set { equipmentRaw = newValue.map(\.rawValue) }
        }

        public var limitationAreas: [BodyArea] {
            get { limitationAreasRaw.compactMap(BodyArea.init(rawValue:)) }
            set { limitationAreasRaw = newValue.map(\.rawValue) }
        }

        public var unitSystem: UnitSystem? {
            get { unitSystemRaw.flatMap(UnitSystem.init(rawValue:)) }
            set { unitSystemRaw = newValue?.rawValue }
        }

        /// The most recent bodyweight, from Health or entered by hand.
        public var latestBodyweightKg: Double? {
            bodyweights?.max { $0.date < $1.date }?.kg
        }
    }

    @Model public final class BodyweightEntry {
        public var date = Date.now
        public var kg = 0.0
        /// Set when the value came from Health, so it isn't imported twice.
        public var healthKitSampleID: UUID?
        public var profile: Profile?

        public init(date: Date = .now, kg: Double, healthKitSampleID: UUID? = nil) {
            self.date = date
            self.kg = kg
            self.healthKitSampleID = healthKitSampleID
        }
    }

    /// An exercise the user added. Library exercises ship in the app bundle and aren't stored;
    /// plans and logs refer to either kind by `exerciseID`.
    @Model public final class CustomExercise {
        /// Prefixed `custom-` so it never collides with a library id.
        public var exerciseID = "custom-\(UUID().uuidString.lowercased())"
        public var createdAt = Date.now
        public var name = ""
        public var aliases: [String] = []
        public var categoryRaw = ExerciseCategory.strength.rawValue
        public var patternRaw = MovementPattern.isolation.rawValue
        public var primaryMusclesRaw: [String] = []
        public var secondaryMusclesRaw: [String] = []
        public var equipmentRaw: [String] = []
        public var trackingRaw = TrackingType.weightReps.rawValue
        public var isUnilateral = false
        public var difficultyRaw = ExperienceLevel.beginner.rawValue
        public var cues: [String] = []
        public var sportTags: [String] = []

        public init(name: String, category: ExerciseCategory, pattern: MovementPattern, tracking: TrackingType) {
            self.name = name
            self.categoryRaw = category.rawValue
            self.patternRaw = pattern.rawValue
            self.trackingRaw = tracking.rawValue
        }

        public var category: ExerciseCategory {
            get { ExerciseCategory(rawValue: categoryRaw) ?? .strength }
            set { categoryRaw = newValue.rawValue }
        }

        public var pattern: MovementPattern {
            get { MovementPattern(rawValue: patternRaw) ?? .isolation }
            set { patternRaw = newValue.rawValue }
        }

        public var tracking: TrackingType {
            get { TrackingType(rawValue: trackingRaw) ?? .weightReps }
            set { trackingRaw = newValue.rawValue }
        }

        public var difficulty: ExperienceLevel {
            get { ExperienceLevel(rawValue: difficultyRaw) ?? .beginner }
            set { difficultyRaw = newValue.rawValue }
        }

        public var primaryMuscles: [Muscle] {
            get { primaryMusclesRaw.compactMap(Muscle.init(rawValue:)) }
            set { primaryMusclesRaw = newValue.map(\.rawValue) }
        }

        public var secondaryMuscles: [Muscle] {
            get { secondaryMusclesRaw.compactMap(Muscle.init(rawValue:)) }
            set { secondaryMusclesRaw = newValue.map(\.rawValue) }
        }

        public var equipment: [Equipment] {
            get { equipmentRaw.compactMap(Equipment.init(rawValue:)) }
            set { equipmentRaw = newValue.map(\.rawValue) }
        }
    }
}
