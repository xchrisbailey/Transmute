import Foundation
import Testing

@testable import TransmuteCore

/// `Schedule`, `ProgressionSettings` and `WorkoutPreferences` are stored on `Profile` as
/// `Codable` attributes and written to every backup, so their encoding is a promise to the
/// CloudKit store and to people's files. The literals were captured from the code at
/// `a594643`, before their decoding tolerated a missing member.
struct NestedSettingsStorageTests {
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
    static let schedulePlist = """
        YnBsaXN0MDDVAQIDBAUGBwkKC1tkYXlzUGVyV2Vla18QEXByZWZlcnJlZFdlZWtkYXlzXnNlc3Npb25NaW51dGVzVXdlZWtz\
        W2NvbW1pdG1lbnRzEASiCAYQARAyEAihDNMNDg8QERJXd2Vla2RheVVsYWJlbFlpbnRlbnNpdHkQAltGaXZlLWEtc2lkZVRo\
        YXJkCBMfM0JIVFZZW11fYWhwdoCCjgAAAAAAAAEBAAAAAAAAABMAAAAAAAAAAAAAAAAAAACT
        """
    static let progressionJSON = """
        {"heldExerciseIDs":["back-squat","bench-press"],"lowerBodyKg":2,"lowerBodyLb":10,"upperBodyKg":1,"upperBodyLb":2.5}
        """
    static let progressionPlist = """
        YnBsaXN0MDDVAQIDBAUGBwgJClt1cHBlckJvZHlLZ1tsb3dlckJvZHlLZ1t1cHBlckJvZHlMYltsb3dlckJvZHlMYl8QD2hl\
        bGRFeGVyY2lzZUlEcyM/8AAAAAAAACNAAAAAAAAAACNABAAAAAAAACNAJAAAAAAAAKILDFpiYWNrLXNxdWF0W2JlbmNoLXBy\
        ZXNzCBMfKzdDVV5ncHl8hwAAAAAAAAEBAAAAAAAAAA0AAAAAAAAAAAAAAAAAAACT
        """
    static let defaultPreferencesJSON = """
        {"autoStartRest":true,"restHaptics":true,"restSound":true,"warmUpRestSeconds":45,"warmUpSets":true,"workingRestSeconds":90}
        """
    static let defaultPreferencesPlist = """
        YnBsaXN0MDDWAQIDBAUGBwgJCQkJXxASd29ya2luZ1Jlc3RTZWNvbmRzXxARd2FybVVwUmVzdFNlY29uZHNZcmVzdFNvdW5k\
        W3Jlc3RIYXB0aWNzXWF1dG9TdGFydFJlc3Rad2FybVVwU2V0cyNAVoAAAAAAACNARoAAAAAAAAkIFSo+SFRibXZ/AAAAAAAA\
        AQEAAAAAAAAACgAAAAAAAAAAAAAAAAAAAIA=
        """
    static let chosenPreferencesJSON = """
        {"autoStartRest":false,"restHaptics":false,"restSound":false,"showPercentOfMax":false,"showRPE":true,"warmUpRestSeconds":30,"warmUpSets":false,"workingRestSeconds":120}
        """
    static let chosenPreferencesPlist = """
        YnBsaXN0MDDYAQIDBAUGBwgJCgsLCwwLC18QEndvcmtpbmdSZXN0U2Vjb25kc18QEXdhcm1VcFJlc3RTZWNvbmRzWXJlc3RT\
        b3VuZFtyZXN0SGFwdGljc11hdXRvU3RhcnRSZXN0V3Nob3dSUEVfEBBzaG93UGVyY2VudE9mTWF4Wndhcm1VcFNldHMjQF4A\
        AAAAAAAjQD4AAAAAAAAICQgZLkJMWGZugYyVnp8AAAAAAAABAQAAAAAAAAANAAAAAAAAAAAAAAAAAAAAoA==
        """

    private func json(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try #require(String(bytes: try encoder.encode(value), encoding: .utf8))
    }

    private func plist(_ value: some Encodable) throws -> String {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(value).base64EncodedString()
    }

    @Test func scheduleEncodesToTheBytesItAlwaysDid() throws {
        #expect(try json(Self.schedule) == Self.scheduleJSON)
        #expect(try plist(Self.schedule) == Self.schedulePlist)
    }

    @Test func progressionSettingsEncodeToTheBytesTheyAlwaysDid() throws {
        #expect(try json(Self.progression) == Self.progressionJSON)
        #expect(try plist(Self.progression) == Self.progressionPlist)
    }

    @Test func preferencesEncodeToTheBytesTheyAlwaysDid() throws {
        #expect(try json(Self.defaultPreferences) == Self.defaultPreferencesJSON)
        #expect(try plist(Self.defaultPreferences) == Self.defaultPreferencesPlist)
        #expect(try json(Self.chosenPreferences) == Self.chosenPreferencesJSON)
        #expect(try plist(Self.chosenPreferences) == Self.chosenPreferencesPlist)
    }

    @Test func storedJSONDecodesAndEncodesToTheSameBytes() throws {
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

    @Test func storedPlistDecodesAndEncodesToTheSameBytes() throws {
        func decode<Value: Codable>(_ type: Value.Type, _ stored: String) throws -> Value {
            try PropertyListDecoder().decode(type, from: try #require(Data(base64Encoded: stored)))
        }
        let schedule = try decode(Schedule.self, Self.schedulePlist)
        #expect(schedule == Self.schedule)
        #expect(try plist(schedule) == Self.schedulePlist)
        let progression = try decode(ProgressionSettings.self, Self.progressionPlist)
        #expect(progression == Self.progression)
        #expect(try plist(progression) == Self.progressionPlist)
        for (stored, expected) in [
            (Self.defaultPreferencesPlist, Self.defaultPreferences),
            (Self.chosenPreferencesPlist, Self.chosenPreferences),
        ] {
            let preferences = try decode(WorkoutPreferences.self, stored)
            #expect(preferences == expected)
            #expect(try plist(preferences) == stored)
        }
    }
}
