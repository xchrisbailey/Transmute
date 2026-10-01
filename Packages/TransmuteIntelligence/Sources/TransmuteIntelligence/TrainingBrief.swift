import Foundation
import TransmuteCore

/// Everything a planning prompt needs to know about the person, as a plain value. Built from
/// the profile in the app (#9), or by hand in tests and evaluations.
public struct TrainingBrief: Codable, Hashable, Sendable {
    public var heightCm: Double?
    public var weightKg: Double?
    public var age: Int?
    public var sex: Sex?
    public var experience: ExperienceLevel
    /// The goal in the person's own words.
    public var goal: String
    public var goalTags: [GoalTag]
    /// Optional, e.g. ["tennis, 4.0 NTRP, plays 3× a week"].
    public var sports: [String]
    public var schedule: Schedule
    public var equipment: Set<Equipment>
    /// Injuries and no-go movements in plain words.
    public var limitations: String
    /// Body areas to protect, from the chips and from the words above.
    public var limitationAreas: Set<BodyArea>
    /// Lifts the person knows their numbers for.
    public var knownLifts: [KnownLift]
    /// Other training this week from Health, e.g. tennis, described for the prompt.
    public var outsideLoad: String?

    public init(
        heightCm: Double? = nil, weightKg: Double? = nil, age: Int? = nil, sex: Sex? = nil,
        experience: ExperienceLevel = .beginner, goal: String = "", goalTags: [GoalTag] = [], sports: [String] = [],
        schedule: Schedule = Schedule(), equipment: Set<Equipment> = [.bodyweight], limitations: String = "",
        limitationAreas: Set<BodyArea> = [], knownLifts: [KnownLift] = [], outsideLoad: String? = nil
    ) {
        self.limitationAreas = limitationAreas.union(LimitationRules.areas(mentionedIn: limitations))
        self.knownLifts = knownLifts
        self.outsideLoad = outsideLoad
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.sex = sex
        self.experience = experience
        self.goal = goal
        self.goalTags = goalTags
        self.sports = sports
        self.schedule = schedule
        self.equipment = equipment
        self.limitations = limitations
    }

    /// The person, described for a prompt. Metric, plain English, one fact per line.
    public var promptDescription: String {
        var lines: [String] = []
        var body: [String] = []
        if let age { body.append("\(age) years old") }
        if let sex, sex != .other { body.append(sex.rawValue) }
        if let heightCm { body.append("\(Int(heightCm.rounded())) cm") }
        if let weightKg { body.append("\(Int(weightKg.rounded())) kg") }
        if !body.isEmpty { lines.append("Body: \(body.joined(separator: ", "))") }
        lines.append("Experience: \(experienceDescription)")
        if !goal.isEmpty { lines.append("Goal in their words: \(goal)") }
        if !goalTags.isEmpty { lines.append("Goal tags: \(goalTags.map(\.rawValue).joined(separator: ", "))") }
        if !sports.isEmpty { lines.append("Sport: \(sports.joined(separator: "; "))") }
        lines.append(
            "Schedule: \(schedule.daysPerWeek) days a week, \(schedule.sessionMinutes) minutes a session, "
                + "\(schedule.weeks) weeks")
        if !schedule.preferredWeekdays.isEmpty {
            lines.append(
                "Training days: \(schedule.preferredWeekdays.sorted().map(Self.weekdayName).joined(separator: ", "))")
        }
        for commitment in schedule.commitments.sorted(by: { $0.weekday < $1.weekday }) {
            lines.append(
                "Fixed commitment: \(commitment.label) on \(Self.weekdayName(commitment.weekday)) "
                    + "(\(commitment.intensity.rawValue))")
        }
        let kit = equipment.subtracting([.bodyweight]).map(\.rawValue).sorted()
        lines.append("Equipment: \(kit.isEmpty ? "bodyweight only" : (kit + ["bodyweight"]).joined(separator: ", "))")
        var limits = limitations.isEmpty ? [] : [limitations]
        let areas = limitationAreas.map(\.rawValue).sorted()
        if !areas.isEmpty { limits.append("go easy on: \(areas.joined(separator: ", "))") }
        lines.append("Limitations: \(limits.isEmpty ? "none" : limits.joined(separator: "; "))")
        if let outsideLoad { lines.append("Other training: \(outsideLoad)") }
        return lines.joined(separator: "\n")
    }

    private var experienceDescription: String {
        switch experience {
        case .beginner: "new to training"
        case .intermediate: "trains on and off"
        case .advanced: "trains regularly and knows their numbers"
        }
    }

    /// ISO weekday name: 1 is Monday.
    public static func weekdayName(_ weekday: Weekday) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][(weekday - 1 + 7) % 7]
    }

    /// The brief for a saved profile.
    public init(_ profile: Profile, outsideLoad: String? = nil, now: Date = .now) {
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        self.init(
            heightCm: profile.heightCm, weightKg: profile.latestBodyweightKg, age: profile.birthYear.map { year - $0 },
            sex: profile.sex, experience: profile.experience, goal: profile.goalText, goalTags: profile.goalTags,
            sports: profile.sports, schedule: profile.schedule, equipment: Set(profile.equipment).union([.bodyweight]),
            limitations: profile.limitations, limitationAreas: Set(profile.limitationAreas),
            knownLifts: profile.knownLifts, outsideLoad: outsideLoad)
    }

    /// The library search every tool call starts from: what this person has and can do.
    public var exerciseScope: ExerciseQuery {
        ExerciseQuery(availableEquipment: equipment, maxDifficulty: experience)
    }
}
