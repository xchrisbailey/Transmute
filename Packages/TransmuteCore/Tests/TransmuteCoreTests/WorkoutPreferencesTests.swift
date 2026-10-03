import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct WorkoutPreferencesTests {
    @Test func defaultsSuitSomeoneNew() {
        let preferences = WorkoutPreferences()
        #expect(preferences.workingRestSeconds == 90)
        #expect(preferences.warmUpRestSeconds == 45)
        #expect(preferences.restSound && preferences.restHaptics && preferences.autoStartRest)
        #expect(preferences.warmUpSets)
        #expect(preferences.showRPE == nil && preferences.showPercentOfMax == nil)
        #expect(preferences.restSeconds(isWarmUp: false) == 90)
        #expect(preferences.restSeconds(isWarmUp: true) == 45)
    }

    @Test func effortTermsFollowExperienceUntilChosen() {
        var preferences = WorkoutPreferences()
        #expect(!preferences.showsRPE(for: .beginner))
        #expect(!preferences.showsPercentOfMax(for: .beginner))
        for experience in ExperienceLevel.allCases where experience != .beginner {
            #expect(preferences.showsRPE(for: experience))
            #expect(preferences.showsPercentOfMax(for: experience))
        }
        preferences.showRPE = true
        preferences.showPercentOfMax = false
        #expect(preferences.showsRPE(for: .beginner))
        #expect(!preferences.showsPercentOfMax(for: .advanced))
    }

    @Test func effortDisplayReadsTheProfile() {
        #expect(EffortDisplay(nil) == EffortDisplay(showsRPE: false, showsPercentOfMax: false))
        let profile = Profile()
        #expect(EffortDisplay(profile) == EffortDisplay(showsRPE: false, showsPercentOfMax: false))
        profile.experience = .intermediate
        #expect(EffortDisplay(profile) == .everything)
        profile.preferences.showRPE = false
        #expect(EffortDisplay(profile) == EffortDisplay(showsRPE: false, showsPercentOfMax: true))
    }

    @Test func roundTripsThroughJSON() throws {
        let preferences = WorkoutPreferences(
            workingRestSeconds: 120, warmUpRestSeconds: 30, restSound: false, restHaptics: false,
            autoStartRest: false, showRPE: true, showPercentOfMax: false, warmUpSets: false)
        let data = try JSONEncoder().encode(preferences)
        #expect(try JSONDecoder().decode(WorkoutPreferences.self, from: data) == preferences)
        let untouched = try JSONEncoder().encode(WorkoutPreferences())
        #expect(try JSONDecoder().decode(WorkoutPreferences.self, from: untouched) == WorkoutPreferences())
    }

    @Test func aNewProfileHasTheDefaults() {
        let profile = Profile()
        #expect(profile.preferences == WorkoutPreferences())
        #expect(profile.weightUnit == nil && profile.heightUnit == nil && profile.distanceUnit == nil)
    }

    @Test func savesWithTheProfile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "preferences-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(atPath: url.path + suffix)
            }
        }
        let chosen = WorkoutPreferences(
            workingRestSeconds: 180, restSound: false, autoStartRest: false, showRPE: true, warmUpSets: false)
        func open() throws -> ModelContainer {
            try ModelContainer(
                for: TransmuteStore.schema, migrationPlan: TransmuteMigrationPlan.self,
                configurations: ModelConfiguration(schema: TransmuteStore.schema, url: url, cloudKitDatabase: .none))
        }
        do {
            let container = try open()
            let context = container.mainContext
            #expect(WorkoutPreferences.stored(in: context) == WorkoutPreferences())
            let profile = Profile()
            profile.preferences = chosen
            profile.weightUnit = .imperial
            profile.distanceUnit = .metric
            context.insert(profile)
            try context.save()
        }
        let container = try open()
        let context = container.mainContext
        let profile = try #require(try context.fetch(FetchDescriptor<Profile>()).first)
        #expect(profile.preferences == chosen)
        #expect(profile.preferences.showPercentOfMax == nil)
        #expect(profile.weightUnit == .imperial)
        #expect(profile.heightUnit == nil)
        #expect(profile.distanceUnit == .metric)
        #expect(WorkoutPreferences.stored(in: context) == chosen)
    }

    // MARK: Units

    @Test func eachQuantityFollowsTheSystemUntilChosen() {
        let units = Units(system: .imperial, locale: Locale(identifier: "en_GB"))
        #expect(units.weight == .imperial && units.height == .imperial && units.distance == .imperial)
        let mixed = Units(system: .metric, weight: .imperial, distance: .imperial, locale: Locale(identifier: "en_GB"))
        #expect(mixed.system == .metric)
        #expect(mixed.weightSymbol == "lb")
        #expect(mixed.formatWeight(kg: 79.378_660_8) == "175 lb")
        #expect(abs(mixed.kilograms(fromDisplay: 175) - 79.378_660_8) < 1e-4)
        #expect(mixed.formatHeight(cm: 175) == "175 cm")
        #expect(mixed.formatDistance(meters: 1_609.344) == "1 mi")
    }

    @Test func unitsComeFromTheProfile() {
        #expect(Units(nil, locale: Locale(identifier: "de_DE")).weight == .metric)
        let profile = Profile()
        #expect(Units(profile, locale: Locale(identifier: "en_US")).weight == .imperial)
        profile.unitSystem = .metric
        profile.heightUnit = .imperial
        let units = Units(profile, locale: Locale(identifier: "en_US"))
        #expect(units.weight == .metric && units.distance == .metric)
        #expect(units.formatHeight(cm: 175.26) == "5′9″")
        #expect(units.formatWeight(kg: 100) == "100 kg")
    }

    @Test func theDraftKeepsUnitsChosenOnTheirOwn() {
        let profile = Profile()
        profile.unitSystem = .metric
        profile.weightUnit = .imperial
        var draft = ProfileDraft(profile, locale: Locale(identifier: "en_GB"))
        #expect(draft.units.weight == .imperial)
        #expect(draft.units.height == .metric)
        draft.unitSystem = .imperial
        draft.apply(to: profile)
        #expect(profile.unitSystem == .imperial)
        #expect(profile.weightUnit == .imperial)
        #expect(profile.heightUnit == nil)
    }
}
