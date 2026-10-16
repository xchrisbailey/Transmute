import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// A kit is stored on `Profile` and in every backup, so its `Codable` output is a promise to
/// people's data. The literals were captured from the code at `97dedb2`, before `Hundredths`.
struct PlateStorageTests {
    static let poundKitJSON = """
        {"barKind":"standard","bars":[{"kg":20.411656650451594,"kind":"standard"},{"kg":15.87573295035124,"kind":"light"},{"kg":11.339809250250886,"kind":"ezCurl"},{"kg":24.94758035055195,"kind":"trap"}],"dumbbellStepKg":2.267961850050177,"heaviestDumbbellKg":54.43108440120425,"machineStepKg":4.535923700100354,"plates":[{"kg":20.411656650451594,"pairs":6},{"kg":15.87573295035124,"pairs":2},{"kg":11.339809250250886,"pairs":3},{"kg":4.535923700100354,"pairs":3},{"kg":2.267961850050177,"pairs":3},{"kg":1.1339809250250885,"pairs":3}],"system":"imperial"}
        """
    static let poundKitPlist = "YnBsaXN0MDDXAQIDBAUGBwgJDRgjJiFWc3lzdGVtVGJhcnNXYmFyS2luZFZwbGF0ZXNeZHVtYmJlbGxTdGVwS2dfEBJoZWF2aWVzdER1bWJiZWxsS2ddbWFjaGluZVN0ZXBLZ1hpbXBlcmlhbKQKDxIV0gsMDQ5Ua2luZFJrZ1hzdGFuZGFyZCNANGliVIre2dILDBARVWxpZ2h0I0AvwGARu5OL0gsMExRWZXpDdXJsI0Amrft6YWlj0gsMFhdUdHJhcCNAOPKUoDfz7aYZHB4gIiTSDBoOG1VwYWlycxAG0gwaER0QAtIMGhQfEAPSDBohHyNAEiTJLrRUT9IMGiMfI0ACJMkutFRP0gwaJR8jP/IkyS60VE8jQEs3LcYOfncACAAXAB4AIwArADIAQQBWAGQAbQByAHcAfAB/AIgAkQCWAJwApQCqALEAugC/AMQAzQDUANkA3wDhAOYA6ADtAO8A9AD9AQIBCwEQARkAAAAAAAACAQAAAAAAAAAnAAAAAAAAAAAAAAAAAAABIg=="
    static let kilogramKitJSON = """
        {"barKind":"standard","bars":[{"kg":20,"kind":"standard"},{"kg":15,"kind":"light"},{"kg":10,"kind":"ezCurl"},{"kg":25,"kind":"trap"}],"dumbbellStepKg":2,"heaviestDumbbellKg":24,"machineStepKg":2.5,"plates":[{"kg":20,"pairs":1},{"kg":10,"pairs":2},{"kg":5,"pairs":2},{"kg":2.5,"pairs":2},{"kg":1.25,"pairs":1}],"system":"metric"}
        """
    static let kilogramKitPlist = "YnBsaXN0MDDXAQIDBAUGBwgJDRgkJSFWc3lzdGVtVGJhcnNXYmFyS2luZFZwbGF0ZXNeZHVtYmJlbGxTdGVwS2dfEBJoZWF2aWVzdER1bWJiZWxsS2ddbWFjaGluZVN0ZXBLZ1ZtZXRyaWOkCg8SFdILDA0OVGtpbmRSa2dYc3RhbmRhcmQjQDQAAAAAAADSCwwQEVVsaWdodCNALgAAAAAAANILDBMUVmV6Q3VybCNAJAAAAAAAANILDBYXVHRyYXAjQDkAAAAAAAClGRweICLSDBoOG1VwYWlycxAB0gwaFB0QAtIMGh8dI0AUAAAAAAAA0gwaIR0jQAQAAAAAAADSDBojGyM/9AAAAAAAACNAAAAAAAAAACNAOAAAAAAAAAAIABcAHgAjACsAMgBBAFYAZABrAHAAdQB6AH0AhgCPAJQAmgCjAKgArwC4AL0AwgDLANEA1gDcAN4A4wDlAOoA8wD4AQEBBgEPARgAAAAAAAACAQAAAAAAAAAmAAAAAAAAAAAAAAAAAAABIQ=="

    private func json(_ kit: PlateInventory) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(kit), as: UTF8.self)
    }

    private func plist(_ kit: PlateInventory) throws -> String {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(kit).base64EncodedString()
    }

    @Test(arguments: [
        (PlateInventory.Preset.commercialGym, UnitSystem.imperial, poundKitJSON, poundKitPlist),
        (PlateInventory.Preset.home, UnitSystem.metric, kilogramKitJSON, kilogramKitPlist),
    ])
    func aPresetEncodesToTheBytesItAlwaysDid(
        _ preset: PlateInventory.Preset, _ system: UnitSystem, _ expectedJSON: String, _ expectedPlist: String
    ) throws {
        let kit = PlateInventory(preset, system: system)
        #expect(try json(kit) == expectedJSON)
        #expect(try plist(kit) == expectedPlist)
    }

    @Test(arguments: [poundKitJSON, kilogramKitJSON])
    func storedJSONDecodesAndEncodesToTheSameBytes(_ stored: String) throws {
        let kit = try JSONDecoder().decode(PlateInventory.self, from: Data(stored.utf8))
        #expect(try json(kit) == stored)
    }

    @Test(arguments: [poundKitPlist, kilogramKitPlist])
    func storedPlistDecodesAndEncodesToTheSameBytes(_ stored: String) throws {
        let kit = try PropertyListDecoder().decode(PlateInventory.self, from: try #require(Data(base64Encoded: stored)))
        #expect(try plist(kit) == stored)
    }

    @Test func poundPlatesKeepTheirFractionsThroughKilograms() throws {
        let kit = PlateInventory(.commercialGym, system: .imperial)
        let fractions = [2.5, 1.25]
        for pounds in fractions {
            let kg = kit.kilograms(fromDisplay: pounds)
            #expect(kit.display(kg: kg) == pounds)
            #expect(Hundredths(kg: kg, in: .imperial).inUnit == pounds)
            #expect(Hundredths(kg: kg, in: .imperial).kg(in: .imperial) == kg)
        }
        #expect(Hundredths(kg: kit.kilograms(fromDisplay: 1.25), in: .imperial).count == 125)
        #expect(Hundredths(kg: kit.kilograms(fromDisplay: 2.5), in: .imperial).count == 250)
        #expect(Hundredths(kg: 1.25, in: .metric).count == 125)
    }

    @Test func plateRowsOfOneWeightMergeTheirPairs() {
        var kit = PlateInventory(.commercialGym, system: .metric)
        kit.plates = [
            .init(kg: 20, pairs: 2), .init(kg: 10, pairs: 1), .init(kg: 20, pairs: 1), .init(kg: 20.001, pairs: 3),
            .init(kg: 5, pairs: 1),
        ]
        let merged = kit.mergingSameWeightPlates()
        #expect(merged.plates == [.init(kg: 20, pairs: 6), .init(kg: 10, pairs: 1), .init(kg: 5, pairs: 1)])
        #expect(merged.plates.map(\.id).count == Set(merged.plates.map(\.id)).count)
    }

    @Test func aKitWithOneRowPerWeightIsLeftAlone() {
        let kit = PlateInventory(.commercialGym, system: .imperial)
        #expect(kit.mergingSameWeightPlates() == kit)
    }

    @MainActor @Test func restoringABackupMergesDuplicatePlateRows() throws {
        let source = try TransmuteStore.makeTestContainer()
        let profile = Profile()
        var kit = PlateInventory(.home, system: .metric)
        kit.plates = [.init(kg: 20, pairs: 2), .init(kg: 20, pairs: 1), .init(kg: 10, pairs: 2)]
        profile.plates = kit
        source.mainContext.insert(profile)
        let data = try DataTransfer.exportBackup(from: source.mainContext)

        let target = try TransmuteStore.makeTestContainer()
        try DataTransfer.importBackup(data, into: target.mainContext)

        let restored = try #require(try Profile.canonical(in: target.mainContext))
        #expect(restored.plates.plates == [.init(kg: 20, pairs: 3), .init(kg: 10, pairs: 2)])
        #expect(PlateCalculator(inventory: restored.plates).heaviestKg == PlateCalculator(inventory: kit).heaviestKg)
    }
}
