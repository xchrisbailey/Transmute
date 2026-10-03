import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct WorkoutCSVTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    @Test func exportsOneRowPerSet() throws {
        let custom = CustomExercise(
            name: "Sled drag, backwards", category: .conditioning, pattern: .locomotion, tracking: .distanceTime)
        context.insert(custom)
        let workout = Workout(title: "Lower \"A\"", startedAt: Date(timeIntervalSince1970: 1_790_000_000))
        let squat = LoggedExercise(exerciseID: "back-squat", order: 0)
        let warmUp = LoggedSet(order: 0, weightKg: 60, reps: 5)
        warmUp.isWarmUp = true
        warmUp.complete()
        let top = LoggedSet(order: 1, weightKg: 92.5, reps: 5, rpe: 8.5)
        top.notes = "Slow,\nbut moved"
        top.complete()
        squat.sets = [top, warmUp]
        let drag = LoggedExercise(exerciseID: custom.exerciseID, order: 1)
        drag.sets = [LoggedSet(order: 0, seconds: 42.5, meters: 20)]
        let gone = LoggedExercise(exerciseID: "retired-exercise", order: 2)
        gone.sets = [LoggedSet(order: 0, reps: 10)]
        workout.exercises = [gone, drag, squat]
        context.insert(workout)
        try context.save()

        let text = try #require(String(data: try DataTransfer.exportCSV(from: context), encoding: .utf8))

        let id = custom.exerciseID
        #expect(
            text
                == [
                    "date,workout,exercise,exercise_id,set_order,weight_kg,reps,seconds,meters,rpe,warm_up,completed,notes",
                    #"2026-09-21T14:13:20Z,"Lower ""A""",Back squat,back-squat,1,60,5,,,,true,true,"#,
                    "2026-09-21T14:13:20Z,\"Lower \"\"A\"\"\",Back squat,back-squat,2,92.5,5,,,8.5,false,true,\"Slow,\nbut moved\"",
                    #"2026-09-21T14:13:20Z,"Lower ""A""","Sled drag, backwards",\#(id),1,,,42.5,20,,false,false,"#,
                    #"2026-09-21T14:13:20Z,"Lower ""A""",retired-exercise,retired-exercise,1,,10,,,,false,false,"#,
                    "",
                ].joined(separator: "\r\n"))

        // What was written reads back field for field.
        let rows = CSV.rows(text)
        #expect(rows.count == 5)
        #expect(rows.allSatisfy { $0.count == WorkoutCSV.header.count })
        #expect(rows[2][1] == "Lower \"A\"")
        #expect(rows[2][12] == "Slow,\nbut moved")
        #expect(rows[3][2] == "Sled drag, backwards")
    }

    @Test func anEmptyStoreExportsTheHeaderAlone() throws {
        let text = String(data: try DataTransfer.exportCSV(from: context), encoding: .utf8)
        #expect(text == WorkoutCSV.header.joined(separator: ",") + "\r\n")
    }

    @Test func sampleExportHasARowForEverySet() throws {
        SampleData.insert(into: context)
        try context.save()
        let text = try #require(String(data: try DataTransfer.exportCSV(from: context), encoding: .utf8))
        #expect(CSV.rows(text).count == 1 + (try context.fetchCount(FetchDescriptor<LoggedSet>())))
    }

    @Test func readsQuotesSemicolonsAndAnyLineEnding() {
        #expect(
            CSV.rows("a,b\r\n1,\"x, \"\"y\"\"\"\n\n2,\r3,z") == [
                ["a", "b"], ["1", "x, \"y\""], ["2", ""], ["3", "z"],
            ])
        #expect(CSV.rows("\u{FEFF}a;b;c\n1;\"2;3\";4,5\n") == [["a", "b", "c"], ["1", "2;3", "4,5"]])
        #expect(CSV.rows("").isEmpty)
        #expect(CSV.field("plain") == "plain")
        #expect(CSV.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }
}
