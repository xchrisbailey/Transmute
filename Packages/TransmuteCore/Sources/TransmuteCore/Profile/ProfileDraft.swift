import Foundation

/// The profile while it's being entered or edited, as a plain value. Onboarding (#6) and the
/// Profile screen both work on a draft and only write it to the stored `Profile` when saved.
///
/// Only height, weight and days per week are required; everything else has a sensible default
/// so every later step can be skipped (#22).
public struct ProfileDraft: Equatable, Sendable {
    public var heightCm: Double?
    public var weightKg: Double?
    public var birthYear: Int?
    public var sex: Sex?
    public var unitSystem: UnitSystem
    /// Units chosen on their own in Settings (#18). The draft carries them so its screens show
    /// the same units as the rest of the app; `nil` follows `unitSystem`.
    public var weightUnit: UnitSystem?
    public var heightUnit: UnitSystem?
    public var distanceUnit: UnitSystem?
    public var experience: ExperienceLevel
    public var knownLifts: [KnownLift]
    public var goalText: String
    public var goalTags: [GoalTag]
    /// e.g. "tennis, 4.0 NTRP, plays 3× a week". Empty when there's no sport.
    public var sport: String
    public var schedule: Schedule
    public var equipment: Set<Equipment>
    public var plates: PlateInventory
    public var limitations: String
    public var limitationAreas: Set<BodyArea>

    public init(locale: Locale = .current) {
        heightCm = nil
        weightKg = nil
        birthYear = nil
        sex = nil
        unitSystem = .preferred(for: locale)
        experience = .beginner
        knownLifts = []
        goalText = ""
        goalTags = []
        sport = ""
        schedule = Schedule(daysPerWeek: 3, preferredWeekdays: [1, 3, 5], sessionMinutes: 45, weeks: 8)
        equipment = EquipmentPreset.homeDumbbells.equipment
        plates = PlateInventory(.commercialGym, system: unitSystem)
        limitations = ""
        limitationAreas = []
    }

    /// A draft of a stored profile, for editing.
    public init(_ profile: Profile, locale: Locale = .current) {
        self.init(locale: locale)
        heightCm = profile.heightCm
        weightKg = profile.latestBodyweightKg
        birthYear = profile.birthYear
        sex = profile.sex
        unitSystem = profile.unitSystem ?? .preferred(for: locale)
        weightUnit = profile.weightUnit
        heightUnit = profile.heightUnit
        distanceUnit = profile.distanceUnit
        experience = profile.experience
        knownLifts = profile.knownLifts
        goalText = profile.goalText
        goalTags = profile.goalTags
        sport = profile.sports.first ?? ""
        schedule = profile.schedule
        equipment = Set(profile.equipment)
        plates = profile.plates
        limitations = profile.limitations
        limitationAreas = Set(profile.limitationAreas)
    }

    /// The units the draft's screens show values in.
    public var units: Units {
        Units(system: unitSystem, weight: weightUnit, height: heightUnit, distance: distanceUnit)
    }

    /// The chosen bar's weight; setting it changes that bar in `plates`.
    public var barbellKg: Double {
        get { plates.barKg }
        set { plates.setBarKg(newValue) }
    }

    // MARK: Validation

    public static let heightRange = 120.0...230.0
    public static let weightRange = 30.0...300.0
    public static let daysRange = 1...7
    public static let sessionRange = 15...120
    public static let weeksRange = 2...16

    public func birthYearRange(now: Date = .now) -> ClosedRange<Int> {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        return (year - 100)...(year - 13)
    }

    public enum Issue: Equatable, Sendable {
        case heightMissing, heightOutOfRange, weightMissing, weightOutOfRange, birthYearOutOfRange
        case daysOutOfRange, weekdaysDontMatchDays
    }

    /// What has to change before the body step can continue: height and weight, in range.
    public var bodyIssues: [Issue] {
        var issues: [Issue] = []
        if let heightCm {
            if !Self.heightRange.contains(heightCm) { issues.append(.heightOutOfRange) }
        } else {
            issues.append(.heightMissing)
        }
        if let weightKg {
            if !Self.weightRange.contains(weightKg) { issues.append(.weightOutOfRange) }
        } else {
            issues.append(.weightMissing)
        }
        if let birthYear, !birthYearRange().contains(birthYear) { issues.append(.birthYearOutOfRange) }
        return issues
    }

    public var scheduleIssues: [Issue] {
        var issues: [Issue] = []
        if !Self.daysRange.contains(schedule.daysPerWeek) { issues.append(.daysOutOfRange) }
        if !schedule.preferredWeekdays.isEmpty, schedule.preferredWeekdays.count != schedule.daysPerWeek {
            issues.append(.weekdaysDontMatchDays)
        }
        return issues
    }

    public var isComplete: Bool {
        bodyIssues.isEmpty && scheduleIssues.isEmpty
    }

    // MARK: Derived

    /// Whether to show the sport step: a sport goal was picked, or the goal names a sport.
    public var suggestsSport: Bool {
        goalTags.contains(.sportPerformance) || Self.mentionedSport(in: goalText) != nil
    }

    static let sportWords = [
        "tennis", "pickleball", "padel", "squash", "badminton", "running", "marathon", "soccer", "football",
        "basketball", "climbing", "bouldering", "golf", "cycling", "swimming", "rugby", "hockey", "volleyball",
        "court",
    ]

    /// The first sport the goal mentions, e.g. "tennis" in "play better tennis".
    public static func mentionedSport(in text: String) -> String? {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        return sportWords.first { words.contains($0) }
    }

    /// Spreads training days through the week, avoiding the days before hard commitments.
    public static func suggestedWeekdays(days: Int, commitments: [Commitment] = []) -> [Weekday] {
        let spreads: [Int: [Weekday]] = [
            1: [3], 2: [2, 5], 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 3, 5, 6], 6: [1, 2, 3, 4, 5, 6],
            7: [1, 2, 3, 4, 5, 6, 7],
        ]
        let count = min(max(days, 1), 7)
        let busy = Set(commitments.map(\.weekday))
        let free = (1...7).filter { !busy.contains($0) }
        let preferred = (spreads[count] ?? []).filter { !busy.contains($0) }
        // Fill from the remaining free days, then from commitment days if the week is full.
        var picked = preferred
        for day in free + Array(busy).sorted() where picked.count < count && !picked.contains(day) {
            picked.append(day)
        }
        return picked.sorted()
    }

    // MARK: Saving

    /// Writes the draft onto a profile. A changed weight is added as a new bodyweight entry,
    /// dated `date`; earlier entries are kept as history.
    public func apply(to profile: Profile, on date: Date = .now) {
        profile.heightCm = heightCm
        profile.birthYear = birthYear
        profile.sex = sex
        profile.unitSystem = unitSystem
        profile.weightUnit = weightUnit
        profile.heightUnit = heightUnit
        profile.distanceUnit = distanceUnit
        profile.experience = experience
        profile.knownLifts = experience == .beginner ? [] : knownLifts
        profile.goalText = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.goalTags = goalTags
        let sport = sport.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.sports = sport.isEmpty ? [] : [sport]
        var schedule = schedule
        if sport.isEmpty { schedule.commitments = [] }
        if schedule.preferredWeekdays.count != schedule.daysPerWeek {
            schedule.preferredWeekdays = Self.suggestedWeekdays(
                days: schedule.daysPerWeek, commitments: schedule.commitments)
        }
        profile.schedule = schedule
        profile.equipment = Equipment.allCases.filter(equipment.contains)
        profile.plates = plates
        profile.barbellKg = plates.barKg
        profile.limitations = limitations.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.limitationAreas = BodyArea.allCases.filter(limitationAreas.contains)
        if let weightKg, profile.latestBodyweightKg.map({ abs($0 - weightKg) > 0.05 }) ?? true {
            profile.bodyweights?.append(BodyweightEntry(date: date, kg: weightKg))
        }
    }

    /// Fills empty fields from Health, keeping anything already entered.
    public mutating func prefill(from metrics: HealthBodyMetrics) {
        heightCm = heightCm ?? metrics.heightCm
        weightKg = weightKg ?? metrics.weightKg
        birthYear = birthYear ?? metrics.birthYear
        sex = sex ?? metrics.sex
    }
}

/// Quick starts for the equipment step.
public enum EquipmentPreset: String, CaseIterable, Sendable {
    case fullGym, homeDumbbells, bodyweightOnly

    public var equipment: Set<Equipment> {
        switch self {
        case .fullGym:
            Set(Equipment.allCases).subtracting([.pool, .climbingRope, .sled, .flexBar, .hurdle, .ladder])
        case .homeDumbbells:
            [.dumbbell, .bench, .band, .bodyweight]
        case .bodyweightOnly:
            [.bodyweight]
        }
    }

    /// The preset this kit matches exactly, if any.
    public static func matching(_ equipment: Set<Equipment>) -> EquipmentPreset? {
        allCases.first { $0.equipment == equipment }
    }
}
