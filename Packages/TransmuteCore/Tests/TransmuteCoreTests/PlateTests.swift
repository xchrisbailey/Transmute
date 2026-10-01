import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

struct PlateTests {
    let gymKg = PlateInventory(.commercialGym, system: .metric)
    let gymLb = PlateInventory(.commercialGym, system: .imperial)
    let homeKg = PlateInventory(.home, system: .metric)
    let lb = Units(system: .imperial)

    // MARK: Calculator

    @Test func exactInKilograms() throws {
        let calculator = PlateCalculator(inventory: gymKg)
        let hundred = try #require(calculator.solve(kg: 100).exact)
        #expect(hundred.perSide == [25, 15])
        #expect(hundred.total == 100)
        #expect(try #require(calculator.solve(kg: 147.5).exact).perSide == [25, 25, 10, 2.5, 1.25])
    }

    @Test func exactInPoundsHasNoFloatDrift() throws {
        let calculator = PlateCalculator(inventory: gymLb)
        let squat = try #require(calculator.solve(kg: lb.kilograms(fromDisplay: 225)).exact)
        #expect(squat.perSide == [45, 45])
        #expect(squat.total == 225)
        let odd = try #require(calculator.solve(kg: lb.kilograms(fromDisplay: 190)).exact)
        #expect(odd.perSide == [45, 25, 2.5])
        #expect(abs(odd.totalKg * Units.poundsPerKilogram - 190) < 1e-9)
    }

    @Test func impossibleGivesNearestBelowAndAbove() throws {
        let kg = PlateCalculator(inventory: gymKg).solve(kg: 101)
        #expect(kg.exact == nil)
        #expect(kg.below?.total == 100)
        #expect(kg.above?.total == 102.5)
        #expect(kg.nearest?.total == 100)

        let pounds = PlateCalculator(inventory: gymLb).solve(kg: lb.kilograms(fromDisplay: 137.5))
        #expect(!pounds.isExact)
        #expect(pounds.below?.total == 135)
        #expect(pounds.above?.total == 140)
        #expect(pounds.above?.perSide == [45, 2.5])
    }

    @Test func limitedInventoryStopsAtWhatThePlatesMake() throws {
        let calculator = PlateCalculator(inventory: homeKg)
        #expect(calculator.heaviestKg == 132.5)
        let solution = calculator.solve(kg: 150)
        #expect(solution.exact == nil)
        #expect(solution.above == nil)
        #expect(solution.below?.perSide == [20, 10, 10, 5, 5, 2.5, 2.5, 1.25])
        #expect(solution.nearest?.total == 132.5)
    }

    @Test func backsOffWhenGreedyRunsOut() throws {
        var inventory = gymKg
        inventory.plates = [.init(kg: 25, pairs: 1), .init(kg: 15, pairs: 2)]
        let loading = try #require(PlateCalculator(inventory: inventory).solve(kg: 80).exact)
        #expect(loading.perSide == [15, 15])
    }

    @Test func pairCountsAreRespected() throws {
        var inventory = gymKg
        inventory.plates = [.init(kg: 20, pairs: 1), .init(kg: 10, pairs: 1)]
        let solution = PlateCalculator(inventory: inventory).solve(kg: 100)
        #expect(solution.exact == nil)
        #expect(solution.below?.perSide == [20, 10])
        #expect(solution.above == nil)
    }

    @Test func targetLighterThanTheBar() throws {
        let calculator = PlateCalculator(inventory: gymKg)
        let light = calculator.solve(kg: 15)
        #expect(light.exact == nil)
        #expect(light.below == nil)
        #expect(light.above?.isBarOnly == true)
        #expect(light.nearest?.total == 20)
        #expect(try #require(calculator.solve(kg: 20).exact).isBarOnly)
    }

    @Test func otherBars() throws {
        var curlBar = gymKg
        curlBar.barKind = .ezCurl
        let curl = try #require(PlateCalculator(inventory: curlBar).solve(kg: 30).exact)
        #expect(curl.bar.kind == .ezCurl)
        #expect(curl.perSide == [10])

        let trap = PlateCalculator(inventory: gymLb, bar: .trap)
        let pull = try #require(trap.solve(kg: lb.kilograms(fromDisplay: 145)).exact)
        #expect(pull.perSide == [45])
        #expect(pull.total == 145)
    }

    @Test func warmUpRampRoundsDown() {
        let calculator = PlateCalculator(inventory: gymKg)
        let ramp = calculator.warmUps(to: 100)
        #expect(ramp.map(\.reps) == [10, 5, 3, 2])
        #expect(ramp.map(\.loading.total) == [20, 40, 60, 80])
        #expect(ramp.first?.loading.isBarOnly == true)
        #expect(calculator.warmUps(to: 30).map(\.loading.total) == [20, 22.5])
        #expect(calculator.warmUps(to: 20).isEmpty)
    }

    @Test func compactText() throws {
        let english = Locale(identifier: "en_US")
        let loading = try #require(PlateCalculator(inventory: homeKg).solve(kg: 85).exact)
        #expect(PlateText.compact(loading, locale: english) == "per side: 20 · 10 · 2.5")
        let bar = try #require(PlateCalculator(inventory: homeKg).solve(kg: 20).exact)
        #expect(PlateText.compact(bar, locale: english) == "just the bar")
    }

    // MARK: Rounding

    @Test func roundingBarbellToThePlates() {
        #expect(LoadableWeight.round(101, for: [.barbell, .rack], inventory: gymKg) == 100)
        #expect(LoadableWeight.round(101.5, for: [.barbell], inventory: gymKg) == 102.5)
        #expect(LoadableWeight.round(10, for: [.barbell], inventory: gymKg) == 20)
        #expect(LoadableWeight.round(200, for: [.barbell], inventory: homeKg) == 132.5)
        #expect(LoadableWeight.round(24, for: [.trapBar], inventory: gymKg) == 25)
        let pounds = LoadableWeight.round(lb.kilograms(fromDisplay: 228), for: [.barbell], inventory: gymLb)
        #expect(abs(pounds * Units.poundsPerKilogram - 230) < 1e-9)
    }

    @Test func roundingDumbbellsAndMachinesToTheirSteps() {
        #expect(LoadableWeight.round(12.7, for: [.dumbbell, .bench], inventory: homeKg) == 12)
        #expect(LoadableWeight.round(40, for: [.dumbbell], inventory: homeKg) == 24)
        #expect(LoadableWeight.round(0.5, for: [.kettlebell], inventory: homeKg) == 2)
        #expect(LoadableWeight.round(47, for: [.machine], inventory: gymKg) == 45)
        let dumbbell = LoadableWeight.round(lb.kilograms(fromDisplay: 52), for: [.dumbbell], inventory: gymLb)
        #expect(abs(dumbbell * Units.poundsPerKilogram - 50) < 1e-9)
        let cable = LoadableWeight.round(lb.kilograms(fromDisplay: 143), for: [.cable], inventory: gymLb)
        #expect(abs(cable * Units.poundsPerKilogram - 140) < 1e-9)
        // Anything else keeps the plan step.
        #expect(LoadableWeight.round(10.6, for: [.band], inventory: gymKg) == 10)
    }

    @Test func existingRoundingStillWorks() {
        #expect(LoadableWeight.round(101, for: [.barbell], system: .metric) == 100)
        #expect(LoadableWeight.round(13, for: [.dumbbell], system: .metric) == 14)
    }

    // MARK: Presets and storage

    @Test(arguments: PlateInventory.Preset.allCases, UnitSystem.allCases)
    func presetsAreSane(_ preset: PlateInventory.Preset, _ system: UnitSystem) {
        let inventory = PlateInventory(preset, system: system)
        #expect(inventory.preset == preset)
        #expect(inventory.display(kg: inventory.barKg) == (system == .metric ? 20 : 45))
        #expect(Set(inventory.bars.map(\.kind)) == Set(BarKind.allCases))
        let weights = inventory.plates.map { inventory.display(kg: $0.kg) }
        #expect(weights == weights.sorted(by: >))
        #expect(inventory.plates.allSatisfy { $0.pairs > 0 })
        #expect(inventory.dumbbellStepKg > 0 && inventory.heaviestDumbbellKg > inventory.dumbbellStepKg)
        #expect(inventory.machineStepKg > 0)
        // Every preset loads a 100 kg or 225 lb squat, near enough.
        let calculator = PlateCalculator(inventory: inventory)
        #expect(calculator.heaviestKg > 100)
        let squat = calculator.solve(kg: 100)
        #expect(abs((squat.nearest?.totalKg ?? 0) - 100) < 2.5)
    }

    @Test func standardFollowsTheLocale() {
        #expect(PlateInventory.standard(for: Locale(identifier: "en_US")).system == .imperial)
        #expect(PlateInventory.standard(for: Locale(identifier: "de_DE")).system == .metric)
    }

    @Test func inventoryIsCodable() throws {
        var inventory = gymLb
        inventory.barKind = .trap
        inventory.plates[0].pairs = 2
        let data = try JSONEncoder().encode(inventory)
        #expect(try JSONDecoder().decode(PlateInventory.self, from: data) == inventory)
    }

    @MainActor @Test func profileStoresPlatesAndKeepsTheBarInSync() throws {
        let container = try TransmuteStore.makeContainer(.inMemory)
        let profile = Profile()
        container.mainContext.insert(profile)
        var draft = ProfileDraft(profile, locale: Locale(identifier: "en_US"))
        draft.plates = PlateInventory(.home, system: .imperial)
        draft.plates.barKind = .ezCurl
        draft.plates.plates[0].pairs = 3
        draft.apply(to: profile)
        try container.mainContext.save()

        let fresh = ModelContext(container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<Profile>()).first)
        #expect(stored.plates == draft.plates)
        #expect(stored.barbellKg == draft.plates.barKg)
        #expect(stored.plates.display(kg: stored.barbellKg) == 25)
        #expect(ProfileDraft(stored).plates == draft.plates)
    }

    @Test func draftBarbellWeightEditsTheChosenBar() {
        var draft = ProfileDraft(locale: Locale(identifier: "de_DE"))
        #expect(draft.barbellKg == 20)
        draft.barbellKg = 15
        #expect(draft.plates.bar(.standard).kg == 15)
        #expect(draft.plates.preset == nil)
    }
}
