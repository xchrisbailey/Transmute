import Foundation
import Testing
import TransmuteCore

@testable import TransmuteUI

struct RecordFormatTests {
    let metric = Units(system: .metric, locale: Locale(identifier: "en_GB"))
    let imperial = Units(system: .imperial, locale: Locale(identifier: "en_US"))

    func label(_ mark: RecordMark, _ units: Units) -> String {
        String(localized: RecordFormat.label(mark, units: units))
    }

    @Test func labelsReadAsTheBrandBookWritesThem() {
        #expect(label(RecordMark(kind: .repMax, value: 115, reps: 5), metric) == "5RM")
        #expect(label(RecordMark(kind: .estimatedOneRepMax, value: 130), metric) == "Est. 1RM")
        #expect(label(RecordMark(kind: .maxReps, value: 12), metric) == "Max reps")
        #expect(label(RecordMark(kind: .bestTime, value: 2.85, meters: 20), metric) == "Best 20 m")
        #expect(label(RecordMark(kind: .longestTime, value: 90), metric) == "Longest time")
        #expect(label(RecordMark(kind: .longestDistance, value: 2_000), metric) == "Longest distance")
        #expect(label(RecordMark(kind: .sessionVolume, value: 2_500), metric) == "Session volume")
    }

    @Test func valuesUseTheirUnits() {
        #expect(RecordFormat.value(RecordMark(kind: .repMax, value: 115, reps: 5), units: metric) == "115 kg")
        #expect(RecordFormat.value(RecordMark(kind: .repMax, value: 115, reps: 5), units: imperial) == "253.5 lb")
        #expect(RecordFormat.value(RecordMark(kind: .maxReps, value: 12), units: metric) == "12 reps")
        #expect(RecordFormat.value(RecordMark(kind: .bestTime, value: 2.854, meters: 20), units: metric) == "2.85 s")
        #expect(RecordFormat.value(RecordMark(kind: .longestTime, value: 108), units: metric) == "1:48")
        #expect(RecordFormat.value(RecordMark(kind: .longestDistance, value: 2_000), units: metric) == "2 km")
    }

    @Test func goldReadsAsASentence() {
        let mark = RecordMark(kind: .repMax, value: 115, reps: 5)
        let sentence = String(localized: RecordFormat.gold(mark, exercise: "Squat", units: metric))
        #expect(sentence == "Gold. Squat 5RM, 115 kg.")
    }

    @Test(arguments: [
        RecordCopy.estimatedOneRepMax, RecordCopy.repMax(reps: 5), RecordCopy.maxReps,
        RecordCopy.bestTime(distance: "20 m"), RecordCopy.longestTime, RecordCopy.longestDistance,
        RecordCopy.sessionVolume, RecordCopy.reps(12), RecordCopy.title, RecordCopy.also("3RM"),
        RecordCopy.goldThisBlock, RecordCopy.noGoldThisBlock, RecordCopy.empty,
    ])
    func copyIsInTheCatalog(_ resource: LocalizedStringResource) throws {
        let entry = try #require(BrandAssetsTests.catalog[resource.key] as? [String: Any], "\(resource.key) missing")
        let comment = try #require(entry["comment"] as? String)
        let tone = resource.key.split(separator: ".").first.map(String.init) ?? ""
        #expect(comment.hasPrefix("\(tone)."))
        #expect(resource.key.hasPrefix("\(tone).records."))
    }
}
