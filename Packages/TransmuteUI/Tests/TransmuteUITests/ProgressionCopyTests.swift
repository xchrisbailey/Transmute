import Foundation
import Testing
import TransmuteCore

@testable import TransmuteUI

/// The "From your plan" sentences built from the engine's reasons.
struct ProgressionCopyTests {
    static let locale = Locale(identifier: "en_US")
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!  // swiftlint:disable:this force_unwrapping
        calendar.locale = locale
        return calendar
    }()
    static let now = Date(timeIntervalSince1970: 1_790_553_600)  // Monday 2026-09-28, UTC.
    static let thursday = now.addingTimeInterval(-4 * 86_400)

    func sentence(_ reason: ProgressionReason, _ system: UnitSystem = .metric) -> String {
        let resource = ProgressionCopy.sentence(
            for: reason, exercise: "Back Squat", units: Units(system: system, locale: Self.locale), now: Self.now,
            calendar: Self.calendar)
        return String(localized: resource)
    }

    func reason(_ kind: ProgressionReason.Kind) -> ProgressionReason {
        ProgressionReason(
            exerciseID: "back-squat", kind: kind, loadKg: 102.5, changeKg: 2.5, change: 5, fraction: 0.9,
            oneRepMaxKg: 140, sets: 3, misses: 3, rpe: 6, targetRPE: 8, sourceDate: Self.thursday)
    }

    @Test func addingLoadReadsLikeTheIssue() {
        #expect(sentence(reason(.addLoad)) == "Back Squat goes up 2.5 kg since every set moved well on Thursday.")
    }

    @Test func imperialSaysPounds() {
        var reason = reason(.addLoad)
        reason.changeKg = 5 / Units.poundsPerKilogram
        #expect(sentence(reason, .imperial) == "Back Squat goes up 5 lb since every set moved well on Thursday.")
    }

    @Test func olderSessionsUseTheDateAndUnknownOnesSayLastTime() {
        var reason = reason(.addLoad)
        reason.sourceDate = Self.now.addingTimeInterval(-25 * 86_400)
        #expect(sentence(reason).hasSuffix("on Sep 3."))
        reason.sourceDate = nil
        #expect(sentence(reason).hasSuffix("moved well last time."))
    }

    @Test func eachKindCarriesItsNumbers() {
        #expect(
            sentence(reason(.calibrate)) == "First time through: today's working sets of Back Squat set the baseline.")
        #expect(
            sentence(reason(.deload))
                == "Deload week: Back Squat drops to 3 sets at 102.5 kg, about 90% of the usual load.")
        #expect(sentence(reason(.held)) == "Back Squat stays at 102.5 kg, as you asked.")
        #expect(
            sentence(reason(.rpeUp))
                == "Back Squat goes up 2.5 kg since the sets felt easier than planned on Thursday: RPE 6 against 8.")
        #expect(
            sentence(reason(.drop))
                == "Back Squat comes down about 10% to 102.5 kg after 3 misses in a row. Build back from there.")
        #expect(sentence(reason(.addTime)) == "Back Squat goes up 5 s since every set was done on Thursday.")
        var distance = reason(.addDistance)
        distance.change = 20
        #expect(sentence(distance) == "Back Squat goes up 20 m since every set was done on Thursday.")
        var percent = reason(.percentOfMax)
        percent.fraction = 0.75
        #expect(sentence(percent) == "Back Squat is 75% of your estimated max of 140 kg: 102.5 kg.")
    }

    @Test func withoutALoadTheSentenceDoesntNeedOne() {
        var reason = reason(.deload)
        reason.loadKg = nil
        #expect(sentence(reason) == "Deload week: Back Squat drops to 3 sets so you recover.")
        reason.kind = .held
        #expect(sentence(reason) == "Back Squat stays where it was, as you asked.")
        reason.kind = .drop
        #expect(sentence(reason) == "Back Squat eases back about 10% after 3 misses in a row.")
    }

    @Test(arguments: ProgressionReason.Kind.allCases)
    func everyKindNamesTheExerciseAndIsInTheCatalog(_ kind: ProgressionReason.Kind) throws {
        let resource = ProgressionCopy.sentence(
            for: reason(kind), exercise: "Back Squat", units: Units(system: .metric, locale: Self.locale))
        #expect(String(localized: resource).contains("Back Squat"))
        let entry = try #require(BrandAssetsTests.catalog[resource.key] as? [String: Any], "\(resource.key)")
        #expect((entry["comment"] as? String)?.hasPrefix("plain.") == true)
    }

    @Test func catalogFormatsMatchTheDefaults() {
        func english(_ key: String) -> String {
            let entry = BrandAssetsTests.catalog[key] as? [String: Any]
            let english = (entry?["localizations"] as? [String: Any])?["en"] as? [String: Any]
            return ((english?["stringUnit"] as? [String: Any])?["value"] as? String) ?? ""
        }
        #expect(
            String(format: english("plain.progression.addLoad"), "Squats", "2.5 kg", "on Thursday")
                == "Squats goes up 2.5 kg since every set moved well on Thursday.")
        #expect(
            String(format: english("plain.progression.drop"), "Squats", "90 kg", "3")
                == "Squats comes down about 10% to 90 kg after 3 misses in a row. Build back from there.")
    }
}
