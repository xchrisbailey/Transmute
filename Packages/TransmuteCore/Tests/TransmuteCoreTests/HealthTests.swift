import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct HealthTests {
    let container: ModelContainer
    let library = ExerciseLibrary.bundled

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    func exercises(_ ids: String...) -> [LibraryExercise] {
        ids.compactMap(library.exercise(id:))
    }

    @Test func infersTheHealthActivityFromTheSession() {
        #expect(
            HealthActivity.infer(from: exercises("back-squat", "romanian-deadlift", "pallof-press"))
                == .traditionalStrength)
        #expect(
            HealthActivity.infer(from: exercises("split-step-reaction", "acceleration-sprint", "pro-agility-shuttle"))
                == .functionalStrength)
        #expect(HealthActivity.infer(from: exercises("assault-bike-intervals")) == .cycling)
        #expect(HealthActivity.infer(from: exercises("hip-90-90")) == .flexibility)
        #expect(HealthActivity.infer(from: []) == .traditionalStrength)
    }

    @Test func tiesGoToTheHeavierTraining() {
        #expect(HealthActivity.infer(from: exercises("box-jump", "back-squat")) == .traditionalStrength)
    }

    @Test func recordsOnlyFinishedWorkouts() throws {
        let context = container.mainContext
        let plan = SampleData.plan(startingOn: Date(timeIntervalSince1970: 1_790_000_000))
        context.insert(plan)
        let workouts = SampleData.workouts(following: plan, weeks: 1)
        let friday = try #require(workouts.last)
        let record = try #require(HealthWorkoutRecord(friday, energyKcal: 320))
        #expect(record.workoutID == friday.id)
        #expect(record.activity == .functionalStrength)
        #expect(record.end == friday.endedAt)
        #expect(record.energyKcal == 320)

        friday.endedAt = nil
        #expect(HealthWorkoutRecord(friday) == nil)
    }

    @Test func prefillKeepsWhatThePersonTyped() {
        let profile = Profile()
        container.mainContext.insert(profile)
        profile.heightCm = 180
        let changed = HealthImport.prefill(
            profile, from: HealthBodyMetrics(heightCm: 175, weightKg: 79, birthYear: 1991, sex: .male))
        #expect(changed)
        #expect(profile.heightCm == 180)
        #expect(profile.birthYear == 1991)
        #expect(profile.sex == .male)
        #expect(profile.latestBodyweightKg == 79)
        #expect(!HealthImport.prefill(profile, from: HealthBodyMetrics(weightKg: 70)))
        #expect(profile.latestBodyweightKg == 79)
    }

    @Test func mergeNeverImportsTwiceOrEchoesOurOwnEntries() {
        let profile = Profile()
        container.mainContext.insert(profile)
        let morning = HealthBodyweight(id: UUID(), date: .now, kg: 79)
        let ours = HealthBodyweight(id: UUID(), date: .now, kg: 78.5, isFromTransmute: true)
        #expect(HealthImport.merge([morning, ours], into: profile) == 1)
        #expect(HealthImport.merge([morning, ours], into: profile) == 0)
        #expect(profile.bodyweights?.count == 1)
        #expect(profile.bodyweights?.first?.healthKitSampleID == morning.id)
    }

    @Test func outsideLoadSumsTheWeek() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let load = OutsideLoad([
            OtherWorkout(id: UUID(), activity: "tennis", start: start, end: start + 5_400),
            OtherWorkout(id: UUID(), activity: "tennis", start: start + 86_400, end: start + 86_400 + 5_400),
            OtherWorkout(id: UUID(), activity: "running", start: start, end: start + 2_400),
        ])
        #expect(load.sessions == 3)
        #expect(load.minutes == 220)
        #expect(load.promptDescription == "3 sessions outside Transmute: tennis 180 min, running 40 min")
        #expect(OutsideLoad([]).promptDescription == "No other training recorded.")
    }

    @Test func everythingWorksWithoutHealth() async throws {
        let health: any HealthService = UnavailableHealthService()
        #expect(!health.isAvailable)
        #expect(await health.accessStatus() == HealthAccessStatus())
        #expect(!health.canSaveBodyweight)
        try await health.requestAccess(.profile)
        #expect(await health.bodyMetrics().isEmpty)
        #expect(await health.otherWorkouts(in: DateInterval(start: .now, duration: 60)).isEmpty)
        await #expect(throws: HealthServiceError.unavailable) {
            try await health.saveBodyweight(kg: 80, at: .now)
        }
    }
}
