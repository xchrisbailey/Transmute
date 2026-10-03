import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

@testable import TransmuteSettingsUI

@MainActor
struct UnitSettingsTests {
    let american = Locale(identifier: "en_US")
    let france = Locale(identifier: "fr_FR")

    @Test func aFreshProfileMatchesTheDevice() {
        let settings = UnitSettings(Profile(), locale: american)
        #expect(settings == UnitSettings(weight: .imperial, height: nil, distance: nil))
    }

    /// Onboarding stores the overall system. While it agrees with the device, height and
    /// distance still read as matching the device; once it doesn't, they're a choice.
    @Test func anOverallSystemCountsAsAChoiceOnlyWhenItDiffers() {
        let profile = Profile()
        profile.unitSystem = .imperial
        #expect(UnitSettings(profile, locale: american).height == nil)
        #expect(
            UnitSettings(profile, locale: france)
                == UnitSettings(weight: .imperial, height: .imperial, distance: .imperial))
        profile.heightUnit = .metric
        #expect(UnitSettings(profile, locale: american).height == .metric)
    }

    @Test func applyingWritesEachUnitAndClearsTheOverallSystem() {
        let profile = Profile()
        profile.unitSystem = .imperial
        var settings = UnitSettings(profile, locale: france)
        settings.weight = .metric
        settings.distance = nil
        settings.apply(to: profile)
        #expect(profile.unitSystem == nil)
        let units = Units(profile, locale: france)
        #expect(units.weight == .metric)
        #expect(units.height == .imperial)
        // Matching the device now means the device, not what onboarding picked.
        #expect(units.distance == .metric)
        #expect(Units(profile, locale: american).distance == .imperial)
        #expect(UnitSettings(profile, locale: france) == settings)
    }

    @Test func effortChoicesRoundTrip() {
        for stored in [nil, true, false] as [Bool?] {
            #expect(EffortChoice(stored).stored == stored)
        }
        #expect(EffortChoice.automatic.label(automaticShows: false).key.hasSuffix("automaticHidden"))
        #expect(EffortChoice.automatic.label(automaticShows: true).key.hasSuffix("automaticShown"))
    }

    @Test func restChoicesKeepAnUnusualStoredValue() {
        #expect(RestChoices.including(90) == WorkoutPreferences.restChoices)
        #expect(RestChoices.including(75).contains(75))
        #expect(RestChoices.including(75) == RestChoices.including(75).sorted())
        #expect(RestChoices.label(90, locale: american) == "1 min, 30 sec")
        #expect(RestChoices.label(45, locale: american) == "45 sec")
    }
}

struct StatusMappingTests {
    @Test func everyCloudStatusHasPlainWords() {
        let all: [CloudSyncStatus] = [
            .notSyncing, .available, .signedOut, .restricted, .temporarilyUnavailable, .unknown,
        ]
        #expect(Set(all.map(\.message.key)).count == all.count)
        for status in all {
            #expect(status.message.key.hasPrefix("plain.settings.icloud."))
        }
        // Only a signed-in, syncing build gets the tick.
        #expect(all.filter { $0.tone == .good } == [.available])
    }

    /// Health never says whether reading was allowed, so "asked" mustn't look like "allowed".
    @Test func beingAskedIsNotShownAsAllowed() {
        #expect(HealthAccessStatus.Write.allowed.tone == .good)
        #expect(HealthAccessStatus.Write.denied.tone == .problem)
        #expect(HealthAccessStatus.Write.notAsked.tone == .off)
        #expect(HealthAccessStatus.Read.asked.tone != .good)
        #expect(String(localized: HealthAccessStatus.Read.asked.label) == "Asked")
        #expect(String(localized: HealthAccessStatus.Read.notAsked.label) == "Not asked yet")
    }

    @Test func everyHealthItemIsNamed() {
        #expect(Set(HealthWriteKind.allCases.map(\.label.key)).count == HealthWriteKind.allCases.count)
        #expect(Set(HealthAccessScope.allCases.map(\.readLabel.key)).count == HealthAccessScope.allCases.count)
    }

    @Test func erasureOutcomesFollowTheCloudStep() {
        #expect(ErasureOutcome(.deleted) == .everywhere)
        #expect(ErasureOutcome(.notSyncing) == .localOnly)
        #expect(ErasureOutcome(.failed(detail: "offline")) == .cloudFailed)
        #expect(String(localized: ErasureOutcome.cloudFailed.message).contains("iCloud couldn't be reached"))
        #expect(!String(localized: ErasureOutcome.localOnly.message).contains("from iCloud."))
    }
}
