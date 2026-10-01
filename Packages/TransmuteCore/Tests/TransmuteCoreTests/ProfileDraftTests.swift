import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct ProfileDraftTests {
    let container: ModelContainer
    let usLocale = Locale(identifier: "en_US")

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    @Test func onlyHeightWeightAndDaysBlock() {
        var draft = ProfileDraft(locale: usLocale)
        #expect(draft.unitSystem == .imperial)
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
        var draft = ProfileDraft(locale: usLocale)
        draft.heightCm = 175
        draft.weightKg = 79
        draft.birthYear = 2024
        #expect(draft.bodyIssues == [.birthYearOutOfRange])
    }

    /// The epic's tennis example, entered step by step, comes out exactly.
    @Test func tennisPlayerSavesExactly() throws {
        var draft = ProfileDraft(locale: usLocale)
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
        #expect(ProfileDraft(profile, locale: usLocale) == draft)
    }

    /// A weight-loss beginner who skips everything optional still gets a usable profile.
    @Test func beginnerWhoSkipsEverythingStillSaves() {
        var draft = ProfileDraft(locale: usLocale)
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
        var draft = ProfileDraft(locale: usLocale)
        draft.heightCm = 170
        draft.weightKg = 80
        draft.apply(to: profile)
        ProfileDraft(profile, locale: usLocale).apply(to: profile)
        #expect(profile.bodyweights?.count == 1)
        draft.weightKg = 79
        draft.apply(to: profile)
        #expect(profile.bodyweights?.count == 2)
        #expect(profile.latestBodyweightKg == 79)
    }

    @Test func sportCommitmentsAreDroppedWithoutASport() {
        let profile = Profile()
        container.mainContext.insert(profile)
        var draft = ProfileDraft(locale: usLocale)
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
        var draft = ProfileDraft(locale: usLocale)
        draft.heightCm = 180
        draft.prefill(from: HealthBodyMetrics(heightCm: 175, weightKg: 80, birthYear: 1990, sex: .female))
        #expect(draft.heightCm == 180)
        #expect(draft.weightKg == 80)
        #expect(draft.birthYear == 1990)
        #expect(draft.sex == .female)
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
