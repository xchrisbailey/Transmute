import Foundation
import TransmuteCore

extension Sex {
    var label: LocalizedStringResource {
        switch self {
        case .female: ProfileCopy.female
        case .male: ProfileCopy.male
        case .other: ProfileCopy.otherSex
        }
    }
}

extension UnitSystem {
    var label: LocalizedStringResource {
        self == .metric ? ProfileCopy.metric : ProfileCopy.imperial
    }
}

extension ExperienceLevel {
    var label: LocalizedStringResource {
        switch self {
        case .beginner: ProfileCopy.beginner
        case .intermediate: ProfileCopy.intermediate
        case .advanced: ProfileCopy.advanced
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .beginner: ProfileCopy.beginnerDetail
        case .intermediate: ProfileCopy.intermediateDetail
        case .advanced: ProfileCopy.advancedDetail
        }
    }
}

/// The goal chips onboarding offers, in order. Other tags stay available to the AI.
enum GoalChoice: CaseIterable {
    case weightLoss, strength, muscle, endurance, mobility, sport

    var tag: GoalTag {
        switch self {
        case .weightLoss: .weightLoss
        case .strength: .strength
        case .muscle: .hypertrophy
        case .endurance: .endurance
        case .mobility: .mobility
        case .sport: .sportPerformance
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .weightLoss: ProfileCopy.goalWeightLoss
        case .strength: ProfileCopy.goalStrength
        case .muscle: ProfileCopy.goalMuscle
        case .endurance: ProfileCopy.goalEndurance
        case .mobility: ProfileCopy.goalMobility
        case .sport: ProfileCopy.goalSport
        }
    }
}

extension Commitment.Intensity: @retroactive CaseIterable {
    public static let allCases: [Commitment.Intensity] = [.light, .moderate, .hard]

    var label: LocalizedStringResource {
        switch self {
        case .light: ProfileCopy.light
        case .moderate: ProfileCopy.moderate
        case .hard: ProfileCopy.hard
        }
    }
}

extension EquipmentPreset {
    var label: LocalizedStringResource {
        switch self {
        case .fullGym: ProfileCopy.fullGym
        case .homeDumbbells: ProfileCopy.homeDumbbells
        case .bodyweightOnly: ProfileCopy.bodyweightOnly
        }
    }
}

extension BodyArea {
    var label: LocalizedStringResource {
        switch self {
        case .neck: ProfileCopy.neck
        case .shoulder: ProfileCopy.shoulder
        case .elbow: ProfileCopy.elbow
        case .wrist: ProfileCopy.wrist
        case .upperBack: ProfileCopy.upperBack
        case .lowerBack: ProfileCopy.lowerBack
        case .hip: ProfileCopy.hip
        case .knee: ProfileCopy.knee
        case .ankle: ProfileCopy.ankle
        }
    }
}

enum WeekdayNames {
    /// ISO weekdays in the locale's words: 1 is Monday.
    static func short(_ weekday: Weekday, calendar: Calendar = .current) -> String {
        calendar.shortWeekdaySymbols[weekday % 7]
    }

    static func full(_ weekday: Weekday, calendar: Calendar = .current) -> String {
        calendar.weekdaySymbols[weekday % 7]
    }
}
