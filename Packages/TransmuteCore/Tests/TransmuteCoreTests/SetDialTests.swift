import Foundation
import Testing

@testable import TransmuteCore

struct SetDialTests {
    let metric = Units(system: .metric, locale: Locale(identifier: "en_GB"))
    let imperial = Units(system: .imperial, locale: Locale(identifier: "en_US"))

    @Test func fieldsFollowHowTheExerciseIsMeasured() {
        func fields(_ tracking: TrackingType) -> [SetField] {
            SetDial(tracking: tracking, units: metric).fields
        }
        #expect(fields(.weightReps) == [.weight, .reps])
        #expect(fields(.reps) == [.reps])
        #expect(fields(.time) == [.seconds])
        #expect(fields(.intervals) == [.seconds])
        #expect(fields(.distanceTime) == [.meters, .seconds])
    }

    @Test func barbellWeightMovesInLoadableSteps() {
        let dial = SetDial(tracking: .weightReps, equipment: [.barbell], units: metric)
        var values = SetValues(weightKg: 80, reps: 5)
        #expect(dial.step(for: .weight, in: values) == 2.5)
        values = dial.adjusting(.weight, by: 1, in: values)
        #expect(values.weightKg == 82.5)
        values = dial.adjusting(.weight, by: -3, in: values)
        #expect(values.weightKg == 75)
        #expect(dial.text(for: .weight, in: values) == "75")
    }

    @Test func dumbbellsStepByTwoKilograms() {
        let dial = SetDial(tracking: .weightReps, equipment: [.dumbbell], units: metric)
        #expect(dial.step(for: .weight, in: SetValues(weightKg: 20)) == 2)
    }

    @Test func poundsStepByFiveAndStoreKilograms() throws {
        let dial = SetDial(tracking: .weightReps, equipment: [.barbell], units: imperial)
        let start = SetValues(weightKg: 225 / Units.poundsPerKilogram, reps: 5)
        let next = dial.adjusting(.weight, by: 1, in: start)
        let kg = try #require(next.weightKg)
        #expect(abs(kg * Units.poundsPerKilogram - 230) < 0.000_1)
        #expect(dial.text(for: .weight, in: next) == "230")
    }

    @Test func oddWeightsSnapToAStep() {
        let dial = SetDial(tracking: .weightReps, equipment: [.barbell], units: metric)
        let values = dial.setting(.weight, to: 81.3, in: SetValues(weightKg: 80))
        #expect(values.weightKg == 82.5)
    }

    @Test func valuesStayInRange() {
        let dial = SetDial(tracking: .weightReps, equipment: [.barbell], units: metric)
        #expect(dial.adjusting(.reps, by: -3, in: SetValues(reps: 1)).reps == 0)
        #expect(dial.adjusting(.weight, by: -1, in: SetValues(weightKg: 0)).weightKg == 0)
        #expect(dial.adjusting(.reps, by: 500, in: SetValues(reps: 1)).reps == 100)
    }

    @Test func timeMovesByFiveSecondsAndReadsAsAClock() {
        let dial = SetDial(tracking: .time, units: metric)
        let values = dial.adjusting(.seconds, by: 1, in: SetValues(seconds: 40))
        #expect(values.seconds == 45)
        #expect(dial.text(for: .seconds, in: values) == "0:45")
    }

    @Test func distanceStepsGrowWithTheDistance() {
        let dial = SetDial(tracking: .distanceTime, units: metric)
        #expect(dial.step(for: .meters, in: SetValues(meters: 20)) == 5)
        #expect(dial.step(for: .meters, in: SetValues(meters: 400)) == 10)
        #expect(dial.step(for: .meters, in: SetValues(meters: 2_000)) == 100)
        #expect(dial.text(for: .meters, in: SetValues(meters: 400)) == "400 m")
    }

    @Test func emptyFieldsShowADashAndStartFromZero() {
        let dial = SetDial(tracking: .weightReps, equipment: [.barbell], units: metric)
        let empty = SetValues()
        #expect(dial.text(for: .weight, in: empty) == "–")
        #expect(dial.value(of: .weight, in: empty) == 0)
        #expect(dial.adjusting(.weight, by: 2, in: empty).weightKg == 5)
    }
}
