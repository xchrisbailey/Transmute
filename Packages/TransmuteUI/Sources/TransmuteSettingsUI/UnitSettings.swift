import Foundation
import TransmuteCore

/// The three unit choices as Settings shows them (#18): weight is always kilograms or pounds,
/// while height and distance can each match the device (`nil`).
///
/// The profile also has an overall system, set in onboarding, which a unit without its own
/// choice follows. Settings writes each unit out and clears the overall one, so "match the
/// device" means the device's region and nothing else.
struct UnitSettings: Equatable {
    var weight: UnitSystem
    var height: UnitSystem?
    var distance: UnitSystem?

    init(weight: UnitSystem, height: UnitSystem? = nil, distance: UnitSystem? = nil) {
        self.weight = weight
        self.height = height
        self.distance = distance
    }

    /// What a profile shows today. An overall system that differs from the device's counts as
    /// a choice for every unit that follows it; one that agrees counts as matching the device.
    init(_ profile: Profile, locale: Locale = .current) {
        let device = UnitSystem.preferred(for: locale)
        let inherited = profile.unitSystem.flatMap { $0 == device ? nil : $0 }
        weight = profile.weightUnit ?? profile.unitSystem ?? device
        height = profile.heightUnit ?? inherited
        distance = profile.distanceUnit ?? inherited
    }

    func apply(to profile: Profile) {
        profile.unitSystem = nil
        profile.weightUnit = weight
        profile.heightUnit = height
        profile.distanceUnit = distance
    }
}

/// Whether sets show RPE or % of 1RM: by experience level until the person chooses (#18).
enum EffortChoice: Hashable, CaseIterable {
    /// Hidden for beginners, shown to everyone else.
    case automatic
    case always
    case never

    init(_ stored: Bool?) {
        switch stored {
        case nil: self = .automatic
        case true?: self = .always
        case false?: self = .never
        }
    }

    /// The value `WorkoutPreferences` stores.
    var stored: Bool? {
        switch self {
        case .automatic: nil
        case .always: true
        case .never: false
        }
    }

    /// The automatic choice says what it currently does, so nobody has to work it out.
    func label(automaticShows: Bool) -> LocalizedStringResource {
        switch self {
        case .automatic:
            automaticShows ? SettingsScreenCopy.effortAutomaticShown : SettingsScreenCopy.effortAutomaticHidden
        case .always: SettingsScreenCopy.effortAlways
        case .never: SettingsScreenCopy.effortNever
        }
    }
}

enum RestChoices {
    /// The rest times to offer: the standard ones, plus the stored one if a backup or another
    /// device brought in something else.
    static func including(_ current: Double) -> [Double] {
        Set(WorkoutPreferences.restChoices + [current]).sorted()
    }

    /// e.g. "45 sec" or "1 min, 30 sec".
    static func label(_ seconds: Double, locale: Locale = .current) -> String {
        Duration.seconds(seconds).formatted(
            .units(allowed: [.minutes, .seconds], width: .abbreviated).locale(locale))
    }
}
