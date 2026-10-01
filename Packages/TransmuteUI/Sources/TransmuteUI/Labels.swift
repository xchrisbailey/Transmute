import Foundation
import TransmuteCore

/// Plain labels for library vocabulary and the picker, from the app's String Catalog.
enum Labels {
    static let searchExercises = LocalizedStringResource(
        "plain.searchExercises", defaultValue: "Search exercises", bundle: .main, comment: "plain. Exercise picker.")

    static let filters = LocalizedStringResource(
        "plain.filters", defaultValue: "Filters", bundle: .main, comment: "plain. Exercise picker.")

    static let filtersOn = LocalizedStringResource(
        "plain.filtersOn", defaultValue: "On", bundle: .main, comment: "plain. Exercise picker.")

    static let filtersOff = LocalizedStringResource(
        "plain.filtersOff", defaultValue: "Off", bundle: .main, comment: "plain. Exercise picker.")

    static let any = LocalizedStringResource(
        "plain.any", defaultValue: "Any", bundle: .main, comment: "plain. Exercise picker.")

    static let category = LocalizedStringResource(
        "plain.category", defaultValue: "Category", bundle: .main, comment: "plain. Exercise picker.")

    static let equipment = LocalizedStringResource(
        "plain.equipment", defaultValue: "Equipment", bundle: .main, comment: "plain. Exercise picker.")

    static let sport = LocalizedStringResource(
        "plain.sport", defaultValue: "Sport", bundle: .main, comment: "plain. Exercise picker.")

    static let sportTags = ["general", "tennis", "running", "soccer", "climbing"]

    static func sport(_ tag: String) -> LocalizedStringResource {
        switch tag {
        case "general":
            LocalizedStringResource(
                "plain.sport.general", defaultValue: "General", bundle: .main, comment: "plain. Sport tag.")
        case "tennis":
            LocalizedStringResource(
                "plain.sport.tennis", defaultValue: "Tennis", bundle: .main, comment: "plain. Sport tag.")
        case "running":
            LocalizedStringResource(
                "plain.sport.running", defaultValue: "Running", bundle: .main, comment: "plain. Sport tag.")
        case "soccer":
            LocalizedStringResource(
                "plain.sport.soccer", defaultValue: "Soccer", bundle: .main, comment: "plain. Sport tag.")
        case "climbing":
            LocalizedStringResource(
                "plain.sport.climbing", defaultValue: "Climbing", bundle: .main, comment: "plain. Sport tag.")
        default:
            LocalizedStringResource(stringLiteral: tag.capitalized)
        }
    }
}

extension ExerciseCategory {
    public var label: LocalizedStringResource {
        switch self {
        case .strength:
            LocalizedStringResource(
                "plain.exerciseCategory.strength", defaultValue: "Strength", bundle: .main,
                comment: "plain. Exercise category.")
        case .power:
            LocalizedStringResource(
                "plain.exerciseCategory.power", defaultValue: "Power", bundle: .main,
                comment: "plain. Exercise category.")
        case .speedAgility:
            LocalizedStringResource(
                "plain.exerciseCategory.speedAgility", defaultValue: "Speed and agility", bundle: .main,
                comment: "plain. Exercise category.")
        case .conditioning:
            LocalizedStringResource(
                "plain.exerciseCategory.conditioning", defaultValue: "Conditioning", bundle: .main,
                comment: "plain. Exercise category.")
        case .mobility:
            LocalizedStringResource(
                "plain.exerciseCategory.mobility", defaultValue: "Mobility and prehab", bundle: .main,
                comment: "plain. Exercise category.")
        }
    }
}

extension Equipment {
    public var label: LocalizedStringResource {
        switch self {
        case .barbell:
            LocalizedStringResource(
                "plain.equipment.barbell", defaultValue: "Barbell", bundle: .main, comment: "plain. Equipment.")
        case .dumbbell:
            LocalizedStringResource(
                "plain.equipment.dumbbell", defaultValue: "Dumbbell", bundle: .main, comment: "plain. Equipment.")
        case .kettlebell:
            LocalizedStringResource(
                "plain.equipment.kettlebell", defaultValue: "Kettlebell", bundle: .main, comment: "plain. Equipment.")
        case .machine:
            LocalizedStringResource(
                "plain.equipment.machine", defaultValue: "Machine", bundle: .main, comment: "plain. Equipment.")
        case .cable:
            LocalizedStringResource(
                "plain.equipment.cable", defaultValue: "Cable", bundle: .main, comment: "plain. Equipment.")
        case .bodyweight:
            LocalizedStringResource(
                "plain.equipment.bodyweight", defaultValue: "Bodyweight", bundle: .main, comment: "plain. Equipment.")
        case .band:
            LocalizedStringResource(
                "plain.equipment.band", defaultValue: "Band", bundle: .main, comment: "plain. Equipment.")
        case .bench:
            LocalizedStringResource(
                "plain.equipment.bench", defaultValue: "Bench", bundle: .main, comment: "plain. Equipment.")
        case .rack:
            LocalizedStringResource(
                "plain.equipment.rack", defaultValue: "Rack", bundle: .main, comment: "plain. Equipment.")
        case .pullUpBar:
            LocalizedStringResource(
                "plain.equipment.pullUpBar", defaultValue: "Pull-up bar", bundle: .main, comment: "plain. Equipment.")
        case .medicineBall:
            LocalizedStringResource(
                "plain.equipment.medicineBall", defaultValue: "Medicine ball", bundle: .main,
                comment: "plain. Equipment.")
        case .box:
            LocalizedStringResource(
                "plain.equipment.box", defaultValue: "Box", bundle: .main, comment: "plain. Equipment.")
        case .sled:
            LocalizedStringResource(
                "plain.equipment.sled", defaultValue: "Sled", bundle: .main, comment: "plain. Equipment.")
        case .ladder:
            LocalizedStringResource(
                "plain.equipment.ladder", defaultValue: "Ladder", bundle: .main, comment: "plain. Equipment.")
        case .cones:
            LocalizedStringResource(
                "plain.equipment.cones", defaultValue: "Cones", bundle: .main, comment: "plain. Equipment.")
        case .rower:
            LocalizedStringResource(
                "plain.equipment.rower", defaultValue: "Rowing machine", bundle: .main, comment: "plain. Equipment.")
        case .bike:
            LocalizedStringResource(
                "plain.equipment.bike", defaultValue: "Bike", bundle: .main, comment: "plain. Equipment.")
        case .treadmill:
            LocalizedStringResource(
                "plain.equipment.treadmill", defaultValue: "Treadmill", bundle: .main, comment: "plain. Equipment.")
        case .jumpRope:
            LocalizedStringResource(
                "plain.equipment.jumpRope", defaultValue: "Jump rope", bundle: .main, comment: "plain. Equipment.")
        case .trapBar:
            LocalizedStringResource(
                "plain.equipment.trapBar", defaultValue: "Trap bar", bundle: .main, comment: "plain. Equipment.")
        case .landmine:
            LocalizedStringResource(
                "plain.equipment.landmine", defaultValue: "Landmine", bundle: .main, comment: "plain. Equipment.")
        case .plate:
            LocalizedStringResource(
                "plain.equipment.plate", defaultValue: "Weight plate", bundle: .main, comment: "plain. Equipment.")
        case .hurdle:
            LocalizedStringResource(
                "plain.equipment.hurdle", defaultValue: "Hurdle", bundle: .main, comment: "plain. Equipment.")
        case .sandbag:
            LocalizedStringResource(
                "plain.equipment.sandbag", defaultValue: "Sandbag", bundle: .main, comment: "plain. Equipment.")
        case .climbingRope:
            LocalizedStringResource(
                "plain.equipment.climbingRope", defaultValue: "Climbing rope", bundle: .main,
                comment: "plain. Equipment.")
        case .dipStation:
            LocalizedStringResource(
                "plain.equipment.dipStation", defaultValue: "Dip station", bundle: .main, comment: "plain. Equipment.")
        case .slider:
            LocalizedStringResource(
                "plain.equipment.slider", defaultValue: "Sliders", bundle: .main, comment: "plain. Equipment.")
        case .stabilityBall:
            LocalizedStringResource(
                "plain.equipment.stabilityBall", defaultValue: "Stability ball", bundle: .main,
                comment: "plain. Equipment.")
        case .foamRoller:
            LocalizedStringResource(
                "plain.equipment.foamRoller", defaultValue: "Foam roller", bundle: .main, comment: "plain. Equipment.")
        case .abWheel:
            LocalizedStringResource(
                "plain.equipment.abWheel", defaultValue: "Ab wheel", bundle: .main, comment: "plain. Equipment.")
        case .pool:
            LocalizedStringResource(
                "plain.equipment.pool", defaultValue: "Pool", bundle: .main, comment: "plain. Equipment.")
        case .flexBar:
            LocalizedStringResource(
                "plain.equipment.flexBar", defaultValue: "Flex bar", bundle: .main, comment: "plain. Equipment.")
        }
    }
}
