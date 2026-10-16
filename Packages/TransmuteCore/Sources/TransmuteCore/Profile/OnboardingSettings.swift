import Foundation

/// The units and plates a new profile starts with. Onboarding asks for them; afterwards
/// Settings owns them, so a `ProfileDraft` never carries them.
public struct OnboardingSettings: Equatable, Sendable {
    /// `nil` follows the device.
    public private(set) var unitSystem: UnitSystem?
    public var plates: PlateInventory

    public init(locale: Locale = .current) {
        unitSystem = nil
        plates = PlateInventory(.commercialGym, system: .preferred(for: locale))
    }

    public func units(locale: Locale = .current) -> Units {
        Units(system: unitSystem, locale: locale)
    }

    /// Picking the device's own system keeps following the device.
    public mutating func select(_ system: UnitSystem, locale: Locale = .current) {
        unitSystem = system == .preferred(for: locale) ? nil : system
    }

    /// The chosen bar's weight; setting it changes that bar in `plates`.
    public var barbellKg: Double {
        get { plates.barKg }
        set { plates.setBarKg(newValue) }
    }

    public func apply(to profile: Profile) {
        profile.unitSystem = unitSystem
        profile.setPlates(plates)
    }
}

extension Profile {
    /// Keeps `barbellKg`, the copy of the chosen bar's weight, in step with the inventory.
    public func setPlates(_ inventory: PlateInventory) {
        plates = inventory
        barbellKg = inventory.barKg
    }
}
