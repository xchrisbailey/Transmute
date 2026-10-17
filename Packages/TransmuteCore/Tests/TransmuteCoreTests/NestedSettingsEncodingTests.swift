import Foundation
import Testing

@testable import TransmuteCore

/// `Schedule`, `ProgressionSettings` and `WorkoutPreferences` are written to every backup through
/// their `Codable` conformance, so this is the encoding backups carry, and a file written by an
/// older build must still decode. It is not what the store holds: SwiftData keeps each of these
/// as a composite attribute with a column per member (`CloudKitSchemaTests` pins those). The
/// literals were captured from the code at `a594643`, before their decoding tolerated a missing
/// member.
struct NestedSettingsEncodingTests {
    static let schedule = Schedule(
        daysPerWeek: 4, preferredWeekdays: [1, 4], sessionMinutes: 50, weeks: 8,
        commitments: [Commitment(weekday: 2, label: "Five-a-side", intensity: .hard)])
    static let progression = ProgressionSettings(
        upperBodyKg: 1, lowerBodyKg: 2, upperBodyLb: 2.5, lowerBodyLb: 10,
        heldExerciseIDs: ["back-squat", "bench-press"])
    static let defaultPreferences = WorkoutPreferences()
    static let chosenPreferences = WorkoutPreferences(
        workingRestSeconds: 120, warmUpRestSeconds: 30, restSound: false, restHaptics: false,
        autoStartRest: false, showRPE: true, showPercentOfMax: false, warmUpSets: false)

    static let scheduleJSON = """
        {"commitments":[{"intensity":"hard","label":"Five-a-side","weekday":2}],"daysPerWeek":4,"preferredWeekdays":[1,4],"sessionMinutes":50,"weeks":8}
        """
    static let progressionJSON = """
        {"heldExerciseIDs":["back-squat","bench-press"],"lowerBodyKg":2,"lowerBodyLb":10,"upperBodyKg":1,"upperBodyLb":2.5}
        """
    static let defaultPreferencesJSON = """
        {"autoStartRest":true,"restHaptics":true,"restSound":true,"warmUpRestSeconds":45,"warmUpSets":true,"workingRestSeconds":90}
        """
    static let chosenPreferencesJSON = """
        {"autoStartRest":false,"restHaptics":false,"restSound":false,"showPercentOfMax":false,"showRPE":true,"warmUpRestSeconds":30,"warmUpSets":false,"workingRestSeconds":120}
        """

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try #require(String(bytes: try encoder.encode(value), encoding: .utf8))
    }

    @Test func scheduleEncodesToTheBytesBackupsAlwaysCarried() throws {
        #expect(try json(Self.schedule) == Self.scheduleJSON)
    }

    @Test func progressionSettingsEncodeToTheBytesBackupsAlwaysCarried() throws {
        #expect(try json(Self.progression) == Self.progressionJSON)
    }

    @Test func preferencesEncodeToTheBytesBackupsAlwaysCarried() throws {
        #expect(try json(Self.defaultPreferences) == Self.defaultPreferencesJSON)
        #expect(try json(Self.chosenPreferences) == Self.chosenPreferencesJSON)
    }

    @Test func writtenJSONDecodesAndEncodesToTheSameBytes() throws {
        let schedule = try JSONDecoder().decode(Schedule.self, from: Data(Self.scheduleJSON.utf8))
        #expect(schedule == Self.schedule)
        #expect(try json(schedule) == Self.scheduleJSON)
        let progression = try JSONDecoder().decode(ProgressionSettings.self, from: Data(Self.progressionJSON.utf8))
        #expect(progression == Self.progression)
        #expect(try json(progression) == Self.progressionJSON)
        for (stored, expected) in [
            (Self.defaultPreferencesJSON, Self.defaultPreferences),
            (Self.chosenPreferencesJSON, Self.chosenPreferences),
        ] {
            let preferences = try JSONDecoder().decode(WorkoutPreferences.self, from: Data(stored.utf8))
            #expect(preferences == expected)
            #expect(try json(preferences) == stored)
        }
    }
}
