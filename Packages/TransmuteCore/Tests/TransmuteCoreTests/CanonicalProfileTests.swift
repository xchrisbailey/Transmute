import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct CanonicalProfileTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeTestContainer()
    }

    @Test func noProfileGivesNil() throws {
        #expect(try Profile.canonical(in: context) == nil)
    }

    @Test func theEarliestMadeWinsAfterASyncDuplicate() throws {
        let later = Profile()
        later.goalText = "Made on the other device"
        later.createdAt = Date(timeIntervalSince1970: 2_000)
        let earlier = Profile()
        earlier.goalText = "Made first"
        earlier.createdAt = Date(timeIntervalSince1970: 1_000)
        context.insert(later)
        context.insert(earlier)
        try context.save()

        #expect(try Profile.canonical(in: context)?.goalText == "Made first")
        #expect(WorkoutPreferences.stored(in: context) == earlier.preferences)
    }

    @Test func aBodyweightLandsOnTheCanonicalProfile() throws {
        let later = Profile()
        later.createdAt = Date(timeIntervalSince1970: 2_000)
        let earlier = Profile()
        earlier.createdAt = Date(timeIntervalSince1970: 1_000)
        context.insert(later)
        context.insert(earlier)

        try BodyweightLog.add(Measurement(value: 80, unit: .kilograms), in: context)

        #expect(earlier.bodyweights?.count == 1)
        #expect(later.bodyweights?.isEmpty == true)
    }
}
