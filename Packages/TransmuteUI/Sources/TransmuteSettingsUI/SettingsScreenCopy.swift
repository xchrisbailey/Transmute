import Foundation

/// Strings for the Settings screen's own controls (#18): units, equipment, appearance and
/// workout. All plain. The appearance names are in `SettingsCopy`, next to `Appearance`.
enum SettingsScreenCopy {
    static let paneGeneral = LocalizedStringResource(
        "plain.settings.pane.general",
        defaultValue: "General",
        bundle: .main, comment: "plain. Mac. Settings tab: units, equipment and appearance.")

    static let paneWorkout = LocalizedStringResource(
        "plain.settings.pane.workout",
        defaultValue: "Workout",
        bundle: .main, comment: "plain. Mac. Settings tab: how a workout runs.")

    static let paneIntelligence = LocalizedStringResource(
        "plain.settings.pane.intelligence",
        defaultValue: "Apple Intelligence",
        bundle: .main, comment: "plain. Settings tab and section heading.")

    static let paneHealth = LocalizedStringResource(
        "plain.settings.pane.health",
        defaultValue: "Health and iCloud",
        bundle: .main, comment: "plain. Mac. Settings tab: Health and iCloud sync.")

    static let paneData = LocalizedStringResource(
        "plain.settings.pane.data",
        defaultValue: "Privacy and data",
        bundle: .main, comment: "plain. Settings tab and section heading: privacy, export, import and delete.")

    static let paneAbout = LocalizedStringResource(
        "plain.settings.pane.about",
        defaultValue: "About",
        bundle: .main, comment: "plain. Settings tab and section heading: version, catalog and font licence.")

    static let needsProfile = LocalizedStringResource(
        "plain.settings.needsProfile",
        defaultValue: "Finish setting up Transmute to change these settings.",
        bundle: .main, comment: "plain. Mac. Shown in Settings before there's a profile.")

    static let units = LocalizedStringResource(
        "plain.settings.units.title",
        defaultValue: "Units",
        bundle: .main, comment: "plain. Section heading.")

    static let weight = LocalizedStringResource(
        "plain.settings.units.weight",
        defaultValue: "Weight",
        bundle: .main, comment: "plain. Picker label: the unit weights are shown in.")

    static let height = LocalizedStringResource(
        "plain.settings.units.height",
        defaultValue: "Height",
        bundle: .main, comment: "plain. Picker label: the unit height is shown in.")

    static let distance = LocalizedStringResource(
        "plain.settings.units.distance",
        defaultValue: "Distance",
        bundle: .main, comment: "plain. Picker label: the unit distances are shown in.")

    static let kilograms = LocalizedStringResource(
        "plain.settings.units.kilograms",
        defaultValue: "Kilograms (kg)",
        bundle: .main, comment: "plain. Weight unit choice.")

    static let pounds = LocalizedStringResource(
        "plain.settings.units.pounds",
        defaultValue: "Pounds (lb)",
        bundle: .main, comment: "plain. Weight unit choice.")

    static let centimetres = LocalizedStringResource(
        "plain.settings.units.centimetres",
        defaultValue: "Centimetres (cm)",
        bundle: .main, comment: "plain. Height unit choice.")

    static let feetAndInches = LocalizedStringResource(
        "plain.settings.units.feetAndInches",
        defaultValue: "Feet and inches",
        bundle: .main, comment: "plain. Height unit choice.")

    static let kilometres = LocalizedStringResource(
        "plain.settings.units.kilometres",
        defaultValue: "Kilometres (km)",
        bundle: .main, comment: "plain. Distance unit choice.")

    static let miles = LocalizedStringResource(
        "plain.settings.units.miles",
        defaultValue: "Miles (mi)",
        bundle: .main, comment: "plain. Distance unit choice.")

    static let matchDevice = LocalizedStringResource(
        "plain.settings.units.matchDevice",
        defaultValue: "Match the device",
        bundle: .main, comment: "plain. Unit choice: follow the region set on the device.")

    static let unitsNote = LocalizedStringResource(
        "plain.settings.units.note",
        defaultValue: """
            Match the device follows the region chosen in the device's own settings. Your plates keep the unit \
            they're marked in.
            """,
        bundle: .main, comment: "plain. Footer under the unit pickers.")

    static let equipment = LocalizedStringResource(
        "plain.settings.equipment.title",
        defaultValue: "Equipment",
        bundle: .main, comment: "plain. Section heading.")

    static let equipmentNote = LocalizedStringResource(
        "plain.settings.equipment.note",
        defaultValue: """
            Bar and plates covers bar weights, the plates you have, dumbbells and machines, with presets for a gym \
            and for a home rack. Progression sets how much weight is added each time.
            """,
        bundle: .main, comment: "plain. Footer under the equipment rows.")

    static let appearance = LocalizedStringResource(
        "plain.settings.appearance.title",
        defaultValue: "Appearance",
        bundle: .main, comment: "plain. Section heading and picker label.")

    static let appearanceNote = LocalizedStringResource(
        "plain.settings.appearance.note",
        defaultValue: "Chosen for this device only.",
        bundle: .main, comment: "plain. Footer under the appearance picker.")

    static let rest = LocalizedStringResource(
        "plain.settings.workout.rest",
        defaultValue: "Rest",
        bundle: .main, comment: "plain. Section heading: rest between sets.")

    static let workingRest = LocalizedStringResource(
        "plain.settings.workout.workingRest",
        defaultValue: "Rest after a set",
        bundle: .main, comment: "plain. Picker label: default rest after a working set.")

    static let warmUpRest = LocalizedStringResource(
        "plain.settings.workout.warmUpRest",
        defaultValue: "Rest after a warm-up set",
        bundle: .main, comment: "plain. Picker label: default rest after a warm-up set.")

    static let restNote = LocalizedStringResource(
        "plain.settings.workout.restNote",
        defaultValue: "Used when your plan doesn't give a set its own rest.",
        bundle: .main, comment: "plain. Footer under the rest time pickers.")

    static let restAlerts = LocalizedStringResource(
        "plain.settings.workout.restAlerts",
        defaultValue: "When rest ends",
        bundle: .main, comment: "plain. Section heading: the rest timer and its alerts.")

    static let autoStartRest = LocalizedStringResource(
        "plain.settings.workout.autoStartRest",
        defaultValue: "Start the rest timer when a set is logged",
        bundle: .main, comment: "plain. Toggle.")

    static let restSound = LocalizedStringResource(
        "plain.settings.workout.restSound",
        defaultValue: "Play a sound when rest ends",
        bundle: .main, comment: "plain. Toggle.")

    static let restHaptics = LocalizedStringResource(
        "plain.settings.workout.restHaptics",
        defaultValue: "Tap when rest ends",
        bundle: .main, comment: "plain. Toggle: a haptic tap on the iPhone and the wrist.")

    static let restHapticsNote = LocalizedStringResource(
        "plain.settings.workout.restHapticsNote",
        defaultValue: "The tap is a short vibration on your iPhone and Apple Watch.",
        bundle: .main, comment: "plain. Footer under the rest alert toggles.")

    static let setsShow = LocalizedStringResource(
        "plain.settings.workout.setsShow",
        defaultValue: "What sets show",
        bundle: .main, comment: "plain. Section heading: which extra numbers appear next to a set.")

    static let showRPE = LocalizedStringResource(
        "plain.settings.workout.showRPE",
        defaultValue: "RPE",
        bundle: .main, comment: "plain. Picker label: whether sets show RPE.")

    static let showPercentOfMax = LocalizedStringResource(
        "plain.settings.workout.showPercentOfMax",
        defaultValue: "% of 1RM",
        bundle: .main, comment: "plain. Picker label: whether sets show the load as a percentage of one-rep max.")

    static let effortAlways = LocalizedStringResource(
        "plain.settings.workout.effort.always",
        defaultValue: "Always show",
        bundle: .main, comment: "plain. Choice for showing RPE or % of 1RM.")

    static let effortNever = LocalizedStringResource(
        "plain.settings.workout.effort.never",
        defaultValue: "Never show",
        bundle: .main, comment: "plain. Choice for showing RPE or % of 1RM.")

    static let effortAutomaticShown = LocalizedStringResource(
        "plain.settings.workout.effort.automaticShown",
        defaultValue: "Match my experience (shown)",
        bundle: .main,
        comment: "plain. Choice for showing RPE or % of 1RM: follow the experience level, which currently shows it.")

    static let effortAutomaticHidden = LocalizedStringResource(
        "plain.settings.workout.effort.automaticHidden",
        defaultValue: "Match my experience (hidden)",
        bundle: .main,
        comment: "plain. Choice for showing RPE or % of 1RM: follow the experience level, which currently hides it.")

    static let effortNote = LocalizedStringResource(
        "plain.settings.workout.effort.note",
        defaultValue: "Match my experience hides both for beginners and shows them to everyone else.",
        bundle: .main, comment: "plain. Footer under the RPE and % of 1RM pickers, after the two glossary lines.")

    static let warmUpSets = LocalizedStringResource(
        "plain.settings.workout.warmUpSets",
        defaultValue: "Warm-up sets",
        bundle: .main, comment: "plain. Toggle.")

    static let warmUpSetsNote = LocalizedStringResource(
        "plain.settings.workout.warmUpSetsNote",
        defaultValue: """
            Lighter sets before barbell lifts, to get ready for the heavy ones. Off leaves them out, including the \
            ones in your plan.
            """,
        bundle: .main, comment: "plain. Footer under the warm-up sets toggle.")
}
