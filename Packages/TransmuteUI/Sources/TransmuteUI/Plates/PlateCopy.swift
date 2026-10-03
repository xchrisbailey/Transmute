import Foundation
import TransmuteCore

/// Strings for the plate sheet and the bar and plates setup (#21). All plain: they're read
/// mid-set.
public enum PlateCopy {
    static let plates = LocalizedStringResource(
        "plain.plates.title", defaultValue: "Plates", bundle: .main,
        comment: "plain. Title of the plate calculator sheet.")

    static let done = LocalizedStringResource(
        "plain.plates.done", defaultValue: "Done", bundle: .main,
        comment: "plain. Closes the plate calculator sheet.")

    static let weight = LocalizedStringResource(
        "plain.plates.weight", defaultValue: "Weight", bundle: .main,
        comment: "plain. Plate sheet stepper that moves to the next loadable weight.")

    static func perSide(_ symbol: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.perSide", defaultValue: "Plates per side (\(symbol))", bundle: .main,
            comment: "plain. Heading over one side's plates; the argument is kg or lb.")
    }

    static let justTheBar = LocalizedStringResource(
        "plain.plates.justTheBar", defaultValue: "Just the bar", bundle: .main,
        comment: "plain. Plate sheet when nothing goes on the bar.")

    static func onBar(_ bar: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.onBar", defaultValue: "On a \(bar) bar", bundle: .main,
            comment: "plain. Under the drawn bar; the argument is the bar's weight, e.g. 20 kg.")
    }

    static func describe(_ plates: String, bar: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.describe", defaultValue: "Each side: \(plates). On a \(bar) bar.", bundle: .main,
            comment: "plain. VoiceOver for the drawn bar; e.g. Each side: 20, 10 and 2.5 kg. On a 20 kg bar.")
    }

    static func describeBarOnly(_ bar: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.describeBarOnly", defaultValue: "Nothing on the bar. Just the \(bar) bar.", bundle: .main,
            comment: "plain. VoiceOver for the drawn bar when it's empty; the argument is e.g. 20 kg.")
    }

    static func cantLoad(_ weight: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.cantLoad", defaultValue: "\(weight) can't be loaded exactly. Pick the nearest:",
            bundle: .main,
            comment: "plain. Plate sheet when the plates can't make the target; the argument is e.g. 101 kg.")
    }

    static func lighterThanBar(_ bar: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.lighterThanBar", defaultValue: "That's lighter than the \(bar) bar.", bundle: .main,
            comment: "plain. Plate sheet when the target is under the bar; the argument is e.g. 20 kg.")
    }

    static let moreThanPlates = LocalizedStringResource(
        "plain.plates.moreThanPlates", defaultValue: "That's more than your plates make.", bundle: .main,
        comment: "plain. Plate sheet when the target is over everything the plates can load.")

    static func lighter(_ weight: String, plates: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.lighter", defaultValue: "Lighter: \(weight), \(plates)", bundle: .main,
            comment: "plain. Nearest loadable weight below; arguments are e.g. 100 kg and 25 · 15 per side.")
    }

    static func heavier(_ weight: String, plates: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.heavier", defaultValue: "Heavier: \(weight), \(plates)", bundle: .main,
            comment: "plain. Nearest loadable weight above; arguments are e.g. 102.5 kg and 25 · 15 · 1.25 per side.")
    }

    // MARK: Setup

    public static let setup = LocalizedStringResource(
        "plain.plates.setup", defaultValue: "Bar and plates", bundle: .main,
        comment: "plain. Title of the equipment setup screen, and its row on the Profile and Settings screens.")

    public static let setupNote = LocalizedStringResource(
        "plain.plates.setupNote",
        defaultValue: "Your bar, plates, dumbbells and machines, so loads round to what you can actually lift.",
        bundle: .main, comment: "plain. Under the Bar and plates row on the Profile screen.")

    static let presets = LocalizedStringResource(
        "plain.plates.presets", defaultValue: "Start from", bundle: .main,
        comment: "plain. Heading over the equipment presets.")

    static let commercialGym = LocalizedStringResource(
        "plain.plates.commercialGym", defaultValue: "Commercial gym", bundle: .main,
        comment: "plain. Equipment preset: a full commercial gym.")

    static let home = LocalizedStringResource(
        "plain.plates.home", defaultValue: "Home set", bundle: .main,
        comment: "plain. Equipment preset: a typical home rack and plates.")

    static let markedIn = LocalizedStringResource(
        "plain.plates.markedIn", defaultValue: "Plates marked in", bundle: .main,
        comment: "plain. Picker for whether the kit is in kilograms or pounds.")

    static let kilograms = LocalizedStringResource(
        "plain.plates.kilograms", defaultValue: "Kilograms", bundle: .main,
        comment: "plain. Kit marked in kilograms.")

    static let pounds = LocalizedStringResource(
        "plain.plates.pounds", defaultValue: "Pounds", bundle: .main,
        comment: "plain. Kit marked in pounds.")

    static let unitNote = LocalizedStringResource(
        "plain.plates.unitNote",
        defaultValue: "Changing this starts the plates over from the preset in that unit.", bundle: .main,
        comment: "plain. Footer under the kit unit picker.")

    static let bar = LocalizedStringResource(
        "plain.plates.bar", defaultValue: "Bar", bundle: .main,
        comment: "plain. Heading and picker for which bar barbell work is loaded on.")

    static let barWeight = LocalizedStringResource(
        "plain.plates.barWeight", defaultValue: "Bar weight", bundle: .main,
        comment: "plain. The chosen bar's weight.")

    static let standardBar = LocalizedStringResource(
        "plain.plates.standardBar", defaultValue: "Standard bar", bundle: .main,
        comment: "plain. A 20 kg or 45 lb Olympic bar.")

    static let lightBar = LocalizedStringResource(
        "plain.plates.lightBar", defaultValue: "Light bar", bundle: .main,
        comment: "plain. A 15 kg or 35 lb Olympic bar.")

    static let ezBar = LocalizedStringResource(
        "plain.plates.ezBar", defaultValue: "EZ bar", bundle: .main,
        comment: "plain. A cambered curl bar.")

    static let trapBar = LocalizedStringResource(
        "plain.plates.trapBar", defaultValue: "Trap bar", bundle: .main,
        comment: "plain. A hex or trap bar.")

    static let platesNote = LocalizedStringResource(
        "plain.plates.platesNote",
        defaultValue: "How many pairs of each plate you have. The calculator never uses more than this.",
        bundle: .main, comment: "plain. Footer under the plate list.")

    static func pairs(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.pairs", defaultValue: "Pairs: \(count)", bundle: .main,
            comment: "plain. How many pairs of a plate there are.")
    }

    static func plateRow(_ weight: String, pairs: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.plates.plateRow", defaultValue: "\(weight) plates, pairs: \(pairs)", bundle: .main,
            comment: "plain. VoiceOver for a plate row; e.g. 2.5 kg plates, pairs: 3.")
    }

    static let newPlate = LocalizedStringResource(
        "plain.plates.newPlate", defaultValue: "New plate", bundle: .main,
        comment: "plain. Field for the weight of a plate to add.")

    static let addPlate = LocalizedStringResource(
        "plain.plates.addPlate", defaultValue: "Add plate", bundle: .main,
        comment: "plain. Adds a plate of the entered weight.")

    static let steps = LocalizedStringResource(
        "plain.plates.steps", defaultValue: "Dumbbells and machines", bundle: .main,
        comment: "plain. Heading over the dumbbell and machine steps.")

    static let stepsNote = LocalizedStringResource(
        "plain.plates.stepsNote",
        defaultValue: "Dumbbell and machine loads round to these steps.", bundle: .main,
        comment: "plain. Footer under the dumbbell and machine steps.")

    static let dumbbellStep = LocalizedStringResource(
        "plain.plates.dumbbellStep", defaultValue: "Dumbbell step", bundle: .main,
        comment: "plain. How much each dumbbell goes up by.")

    static let heaviestDumbbell = LocalizedStringResource(
        "plain.plates.heaviestDumbbell", defaultValue: "Heaviest dumbbell", bundle: .main,
        comment: "plain. The heaviest dumbbell there is.")

    static let machineStep = LocalizedStringResource(
        "plain.plates.machineStep", defaultValue: "Machine stack step", bundle: .main,
        comment: "plain. The step between pins on a machine or cable stack.")
}

extension BarKind {
    var label: LocalizedStringResource {
        switch self {
        case .standard: PlateCopy.standardBar
        case .light: PlateCopy.lightBar
        case .ezCurl: PlateCopy.ezBar
        case .trap: PlateCopy.trapBar
        }
    }
}

extension PlateInventory.Preset {
    var label: LocalizedStringResource {
        switch self {
        case .commercialGym: PlateCopy.commercialGym
        case .home: PlateCopy.home
        }
    }
}
