import Foundation
import Testing

@testable import TransmuteCore

struct UnitsTests {
    let metric = Units(system: .metric, locale: Locale(identifier: "en_GB"))
    let imperial = Units(system: .imperial, locale: Locale(identifier: "en_US"))

    @Test func localePicksTheSystem() {
        #expect(UnitSystem.preferred(for: Locale(identifier: "en_US")) == .imperial)
        #expect(UnitSystem.preferred(for: Locale(identifier: "de_DE")) == .metric)
        #expect(Units(locale: Locale(identifier: "en_US")).system == .imperial)
    }

    @Test func profileOverridesLocale() {
        #expect(Units(system: .metric, locale: Locale(identifier: "en_US")).system == .metric)
    }

    @Test func weightRoundTrips() {
        for kg in [0.0, 2.5, 79.38, 115, 227.5] {
            #expect(abs(imperial.kilograms(fromDisplay: imperial.displayWeight(kg: kg)) - kg) < 1e-9)
            #expect(metric.displayWeight(kg: kg) == kg)
        }
    }

    @Test func formatsWeight() {
        #expect(metric.formatWeight(kg: 115) == "115 kg")
        #expect(metric.formatWeight(kg: 82.4) == "82.5 kg")
        #expect(imperial.formatWeight(kg: 79.378_660_8) == "175 lb")
        #expect(imperial.weightSymbol == "lb")
    }

    @Test func heightConversions() {
        let cm = Units.centimetres(feet: 5, inches: 9)
        #expect(abs(cm - 175.26) < 1e-9)
        #expect(Units.feetAndInches(cm: cm) == (5, 9))
        #expect(Units.feetAndInches(cm: 182.88) == (6, 0))
        #expect(imperial.formatHeight(cm: cm) == "5′9″")
        #expect(metric.formatHeight(cm: cm) == "175 cm")
    }

    @Test func distanceStaysInMetresWhenShort() {
        #expect(imperial.formatDistance(meters: 20) == "20 m")
        #expect(metric.formatDistance(meters: 2_000) == "2 km")
        #expect(imperial.formatDistance(meters: 1_609.344) == "1 mi")
    }

    @Test func clock() {
        #expect(Units.clock(seconds: 108) == "1:48")
        #expect(Units.clock(seconds: 45) == "0:45")
        #expect(Units.clock(seconds: 3_725) == "1:02:05")
    }
}
