import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ProfileDraftTests {
    let container: ModelContainer

    init() throws {
        container = try TransmuteStore.makeTestContainer()
    }

    @Test func onlyHeightWeightAndDaysBlock() {
        var draft = ProfileDraft()
        #expect(draft.bodyIssues == [.heightMissing, .weightMissing])
        #expect(draft.scheduleIssues.isEmpty)
        draft.heightCm = 300
        draft.weightKg = 79
        #expect(draft.bodyIssues == [.heightOutOfRange])
        draft.heightCm = 175
        #expect(draft.isComplete)
        draft.schedule.daysPerWeek = 0
        #expect(draft.scheduleIssues.contains(.daysOutOfRange))
    }

    @Test func birthYearIsOptionalButChecked() {
        var draft = ProfileDraft()
        draft.heightCm = 175
        draft.weightKg = 79
        draft.birthYear = 2024
        #expect(draft.bodyIssues == [.birthYearOutOfRange])
    }

    @Test func tennisPlayerSavesExactly() throws {
        var draft = ProfileDraft()
        draft.heightCm = Units.centimetres(feet: 5, inches: 9)
        draft.weightKg = Units(system: .imperial).kilograms(fromDisplay: 175)
        draft.experience = .intermediate
        draft.goalText = "Improve overall performance on the court"
        draft.goalTags = [.sportPerformance]
        #expect(draft.suggestsSport)
        draft.sport = "tennis, 4.0 NTRP, plays 3× a week"
        draft.schedule = Schedule(
            daysPerWeek: 4, preferredWeekdays: [1, 2, 4, 5], sessionMinutes: 60, weeks: 8,
            commitments: [Commitment(weekday: 6, label: "Match", intensity: .hard)])
        draft.equipment = EquipmentPreset.fullGym.equipment
        draft.knownLifts = [KnownLift(exerciseID: "back-squat", weightKg: 100, reps: 5)]

        let profile = Profile()
        container.mainContext.insert(profile)
        draft.apply(to: profile)
        try container.mainContext.save()

        #expect(Units.feetAndInches(cm: try #require(profile.heightCm)) == (5, 9))
        #expect(Units(system: .imperial).formatWeight(kg: try #require(profile.latestBodyweightKg)) == "175 lb")
        #expect(profile.sports == ["tennis, 4.0 NTRP, plays 3× a week"])
        #expect(profile.schedule.commitments.first?.label == "Match")
        #expect(profile.knownLifts.count == 1)
        #expect(profile.equipment.contains(.barbell))
        #expect(ProfileDraft(profile) == draft)
    }

    @Test func beginnerWhoSkipsEverythingStillSaves() {
        var draft = ProfileDraft()
        draft.heightCm = 165
        draft.weightKg = 92
        draft.goalText = "lose 20 lb before summer"
        draft.goalTags = [.weightLoss]
        draft.knownLifts = [KnownLift(exerciseID: "back-squat", weightKg: 60, reps: 5)]
        #expect(!draft.suggestsSport)

        let profile = Profile()
        container.mainContext.insert(profile)
        draft.apply(to: profile)
        #expect(profile.experience == .beginner)
        #expect(profile.knownLifts.isEmpty, "Beginners are never asked for maxes")
        #expect(profile.schedule.daysPerWeek == 3)
        #expect(profile.schedule.preferredWeekdays == [1, 3, 5])
        #expect(Set(profile.equipment) == EquipmentPreset.homeDumbbells.equipment)
        #expect(profile.sports.isEmpty)
    }

    @Test func savingTheSameWeightDoesNotAddHistory() {
        let profile = Profile()
        container.mainContext.insert(profile)
        var draft = ProfileDraft()
        draft.heightCm = 170
        draft.weightKg = 80
        draft.apply(to: profile)
        ProfileDraft(profile).apply(to: profile)
        #expect(profile.bodyweights?.count == 1)
        draft.weightKg = 79
        draft.apply(to: profile)
        #expect(profile.bodyweights?.count == 2)
        #expect(profile.latestBodyweightKg == 79)
    }

    @Test func sportCommitmentsAreDroppedWithoutASport() {
        let profile = Profile()
        container.mainContext.insert(profile)
        var draft = ProfileDraft()
        draft.schedule.commitments = [Commitment(weekday: 6, label: "Match", intensity: .hard)]
        draft.apply(to: profile)
        #expect(profile.schedule.commitments.isEmpty)
    }

    @Test func goalTextCanSuggestTheSport() {
        #expect(ProfileDraft.mentionedSport(in: "Play better Tennis this summer") == "tennis")
        #expect(ProfileDraft.mentionedSport(in: "lose 20 lb") == nil)
    }

    @Test func suggestedDaysSpreadOutAndAvoidCommitments() {
        #expect(ProfileDraft.suggestedWeekdays(days: 3) == [1, 3, 5])
        let match = Commitment(weekday: 5, label: "Match", intensity: .hard)
        let days = ProfileDraft.suggestedWeekdays(days: 4, commitments: [match])
        #expect(days.count == 4)
        #expect(!days.contains(5))
        #expect(ProfileDraft.suggestedWeekdays(days: 7, commitments: [match]).count == 7)
    }

    @Test func healthPrefillKeepsTypedValues() {
        var draft = ProfileDraft()
        draft.heightCm = 180
        draft.prefill(from: HealthBodyMetrics(heightCm: 175, weightKg: 80, birthYear: 1990, sex: .female))
        #expect(draft.heightCm == 180)
        #expect(draft.weightKg == 80)
        #expect(draft.birthYear == 1990)
        #expect(draft.sex == .female)
    }

    @Test func savingAProfileLeavesSettingsOwnedFieldsAlone() throws {
        let profile = Profile()
        container.mainContext.insert(profile)
        var draft = ProfileDraft(profile)
        draft.heightCm = 175
        draft.weightKg = 79

        profile.unitSystem = .imperial
        profile.weightUnit = .metric
        profile.setPlates(PlateInventory(.home, system: .imperial))
        draft.apply(to: profile)

        #expect(profile.unitSystem == .imperial)
        #expect(profile.weightUnit == .metric)
        #expect(profile.plates == PlateInventory(.home, system: .imperial))
        #expect(profile.barbellKg == profile.plates.barKg)
        #expect(profile.heightCm == 175)
    }

    @Test func presetsMatch() {
        #expect(EquipmentPreset.matching([.bodyweight]) == .bodyweightOnly)
        #expect(EquipmentPreset.matching([.bodyweight, .kettlebell]) == nil)
    }

    @Test func epleyEstimate() {
        #expect(KnownLift(exerciseID: "x", weightKg: 100, reps: 1).estimatedOneRepMaxKg == 100)
        #expect(abs(KnownLift(exerciseID: "x", weightKg: 100, reps: 5).estimatedOneRepMaxKg - 116.67) < 0.01)
    }
}

@MainActor
struct OnboardingSettingsTests {
    let container: ModelContainer
    let american = Locale(identifier: "en_US")
    let german = Locale(identifier: "de_DE")

    init() throws {
        container = try TransmuteStore.makeTestContainer()
    }

    @Test func followsTheDeviceUntilAnotherSystemIsPicked() {
        var settings = OnboardingSettings(locale: american)
        #expect(settings.unitSystem == nil)
        #expect(settings.units(locale: american).weight == .imperial)
        #expect(settings.units(locale: german).weight == .metric)

        settings.select(.metric, locale: american)
        #expect(settings.unitSystem == .metric)
        #expect(settings.units(locale: american).weight == .metric)

        settings.select(.imperial, locale: american)
        #expect(settings.unitSystem == nil)
    }

    @Test func aNewProfileFollowingTheDeviceIsNotPinned() {
        let profile = Profile()
        container.mainContext.insert(profile)
        OnboardingSettings(locale: american).apply(to: profile)
        #expect(profile.unitSystem == nil)
        #expect(profile.plates.system == .imperial)
        #expect(profile.barbellKg == profile.plates.barKg)
    }

    @Test func aNewProfileGetsTheChosenUnitsAndPlates() {
        var settings = OnboardingSettings(locale: american)
        settings.select(.metric, locale: american)
        settings.plates = PlateInventory(.home, system: .metric)
        settings.barbellKg = 15

        let profile = Profile()
        container.mainContext.insert(profile)
        settings.apply(to: profile)
        #expect(profile.unitSystem == .metric)
        #expect(profile.plates == settings.plates)
        #expect(profile.barbellKg == 15)
    }

    @Test func barbellWeightEditsTheChosenBar() {
        var settings = OnboardingSettings(locale: german)
        #expect(settings.barbellKg == 20)
        settings.barbellKg = 15
        #expect(settings.plates.bar(.standard).kg == 15)
        #expect(settings.plates.preset == nil)
    }
}
