import Foundation
import Testing

@testable import TransmuteCore

/// `Commitment`, `KnownLift`, `PlateInventory`, `Bar` and `Plate` are written to every backup through
/// their `Codable` conformance, so this is the encoding backups carry. A lenient decode must not
/// change it. The literals were captured from the code at `8e3ff52`, before any of these decoded
/// leniently.
struct DeeperMemberEncodingTests {
    static let commitment = Commitment(weekday: 6, label: "Match", intensity: .light)
    static let lift = KnownLift(exerciseID: "back-squat", weightKg: 102.5, reps: 5)
    static let kit = PlateInventory(
        system: .metric, bars: [.init(.standard, kg: 20), .init(.ezCurl, kg: 10)], barKind: .ezCurl,
        plates: [.init(kg: 25, pairs: 2), .init(kg: 1.25, pairs: 0)], dumbbellStepKg: 2.5,
        heaviestDumbbellKg: 50, machineStepKg: 5)

    static let commitmentJSON = """
        {"intensity":"light","label":"Match","weekday":6}
        """
    static let liftJSON = """
        {"exerciseID":"back-squat","reps":5,"weightKg":102.5}
        """
    static let kitJSON = """
        {"barKind":"ezCurl","bars":[{"kg":20,"kind":"standard"},{"kg":10,"kind":"ezCurl"}],"dumbbellStepKg":2.5,"heaviestDumbbellKg":50,"machineStepKg":5,"plates":[{"kg":25,"pairs":2},{"kg":1.25,"pairs":0}],"system":"metric"}
        """
    static let barJSON = """
        {"kg":20,"kind":"standard"}
        """
    static let plateJSON = """
        {"kg":25,"pairs":2}
        """

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try #require(String(bytes: try encoder.encode(value), encoding: .utf8))
    }

    private func decoded<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(text.utf8))
    }

    @Test func eachTypeEncodesToTheBytesBackupsAlwaysCarried() throws {
        #expect(try json(Self.commitment) == Self.commitmentJSON)
        #expect(try json(Self.lift) == Self.liftJSON)
        #expect(try json(Self.kit) == Self.kitJSON)
        #expect(try json(Self.kit.bars[0]) == Self.barJSON)
        #expect(try json(Self.kit.plates[0]) == Self.plateJSON)
    }

    @Test func writtenJSONDecodesAndEncodesToTheSameBytes() throws {
        #expect(try decoded(Commitment.self, Self.commitmentJSON) == Self.commitment)
        #expect(try json(decoded(Commitment.self, Self.commitmentJSON)) == Self.commitmentJSON)
        #expect(try decoded(KnownLift.self, Self.liftJSON) == Self.lift)
        #expect(try json(decoded(KnownLift.self, Self.liftJSON)) == Self.liftJSON)
        #expect(try decoded(PlateInventory.self, Self.kitJSON) == Self.kit)
        #expect(try json(decoded(PlateInventory.self, Self.kitJSON)) == Self.kitJSON)
        #expect(try decoded(PlateInventory.Bar.self, Self.barJSON) == Self.kit.bars[0])
        #expect(try decoded(PlateInventory.Plate.self, Self.plateJSON) == Self.kit.plates[0])
    }
}
