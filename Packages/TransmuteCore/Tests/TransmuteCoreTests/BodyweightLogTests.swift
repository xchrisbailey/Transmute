import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct BodyweightLogTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    let metric = Units(system: .metric, locale: Locale(identifier: "en_GB"))
    let imperial = Units(system: .imperial, locale: Locale(identifier: "en_US"))

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    func profile() throws -> Profile {
        let profile = Profile()
        context.insert(profile)
        try context.save()
        return profile
    }

    @Test func anyUnitIsStoredInKilograms() {
        #expect(BodyweightLog.kilograms(Measurement(value: 80, unit: .kilograms)) == 80)
        #expect(BodyweightLog.kilograms(Measurement(value: 175, unit: .pounds)) == 79.38)
        #expect(BodyweightLog.kilograms(Measurement(value: 12, unit: .stones)) == 76.2)
        #expect(BodyweightLog.kilograms(Measurement(value: 79_400, unit: .grams)) == 79.4)
    }

    @Test func addingStoresAnEntryOnTheProfile() throws {
        let profile = try profile()
        let entry = try #require(try BodyweightLog.add(Measurement(value: 175, unit: .pounds), at: now, in: context))
        #expect(entry.kg == 79.38)
        #expect(entry.date == now)
        #expect(entry.healthKitSampleID == nil)
        #expect(profile.bodyweights?.count == 1)
        #expect(profile.latestBodyweightKg == 79.38)
        #expect(!context.hasChanges)
    }

    @Test func aLaterEntryBecomesTheLatest() throws {
        let profile = try profile()
        let yesterday = now.addingTimeInterval(-86_400)
        try BodyweightLog.add(Measurement(value: 80, unit: .kilograms), at: yesterday, in: context)
        try BodyweightLog.add(Measurement(value: 79.5, unit: .kilograms), at: now, in: context)
        #expect(profile.bodyweights?.count == 2)
        #expect(profile.latestBodyweightKg == 79.5)
    }

    @Test(arguments: [0, -5, 12, 29.9, 300.1, 800])
    func weightsNobodyHasAreNotStored(_ kg: Double) throws {
        let profile = try profile()
        #expect(try BodyweightLog.add(Measurement(value: kg, unit: .kilograms), at: now, in: context) == nil)
        #expect(profile.bodyweights?.isEmpty == true)
    }

    @Test func withoutAProfileNothingIsStored() throws {
        #expect(try BodyweightLog.add(Measurement(value: 80, unit: .kilograms), at: now, in: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<BodyweightEntry>()) == 0)
    }

    @Test func spokenFormsSayTheUnitInFull() {
        #expect(BodyweightLog.spoken(kg: 80, units: metric) == "80 kilograms")
        #expect(BodyweightLog.spoken(kg: 79.38, units: metric) == "79.4 kilograms")
        #expect(BodyweightLog.spoken(kg: 79.38, units: imperial) == "175 pounds")
        #expect(BodyweightLog.spoken(kg: 1 / Units.poundsPerKilogram, units: imperial) == "1 pound")
    }
}

struct IndexChangesTests {
    static let first = UUID()
    static let second = UUID()
    static let third = UUID()

    @Test func newAndChangedItemsAreUpdated() {
        let changes = IndexChanges(
            indexed: [Self.first: "Lower A", Self.second: "Upper A"],
            current: [Self.first: "Lower A", Self.second: "Upper B", Self.third: "Speed"])
        #expect(changes.updated == [Self.second, Self.third])
        #expect(changes.removed.isEmpty)
    }

    @Test func itemsThatAreGoneAreRemoved() {
        let changes = IndexChanges(indexed: [Self.first: "Lower A", Self.second: "Upper A"], current: [:])
        #expect(changes.updated.isEmpty)
        #expect(changes.removed == [Self.first, Self.second])
    }

    @Test func nothingChangedIsEmpty() {
        #expect(IndexChanges(indexed: [Self.first: "Lower A"], current: [Self.first: "Lower A"]).isEmpty)
        #expect(IndexChanges(indexed: [:], current: [:]).isEmpty)
    }
}
