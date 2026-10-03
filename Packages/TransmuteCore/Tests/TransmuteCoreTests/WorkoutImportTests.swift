import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

/// Importing Strong and Hevy exports. The fixtures are written by hand in each app's format.
@MainActor
struct WorkoutImportTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let utc = TimeZone(identifier: "UTC")!

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    static let strong = """
        Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,RPE
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Bench Press (Barbell),W,40,8,0,0,,Good session,
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Bench Press (Barbell),1,80,5,0,0,"Paused, first rep",Good session,8
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Bench Press (Barbell),2,82.5,5,0,0,,Good session,8.5
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Bench Press (Barbell),Rest Timer,,,,150,,Good session,
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Overhead Press (Barbell),1,50,6,0,0,,Good session,
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Plank,1,0,0,0,60,,Good session,
        2026-09-14 18:05:00,"Push, heavy",1h 5m,Wrist Roller (Homemade),1,5,10,0,0,,Good session,
        2026-09-16 07:30:00,Pull,45m,Deadlift (Barbell),1,140,3,0,0,,,
        2026-09-16 07:30:00,Pull,45m,Pull Up,1,0,8,0,0,,,
        2026-09-16 07:30:00,Pull,45m,Wrist Roller (Homemade),1,5,12,0,0,,,
        not a date,Pull,45m,Deadlift (Barbell),2,140,3,0,0,,,
        """

    static let hevy = """
        "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_lbs","reps","distance_miles","duration_seconds","rpe"
        "Legs","14 Sep 2026, 18:05","14 Sep 2026, 19:10","Felt strong","Squat (Barbell)",,"Belt on",0,"warmup",135,5,,,
        "Legs","14 Sep 2026, 18:05","14 Sep 2026, 19:10","Felt strong","Squat (Barbell)",,"Belt on",1,"normal",225,5,,,8
        "Legs","14 Sep 2026, 18:05","14 Sep 2026, 19:10","Felt strong","Romanian Deadlift (Barbell)",,"",0,"normal",185,8,,,
        "Legs","14 Sep 2026, 18:05","14 Sep 2026, 19:10","Felt strong","Treadmill Run",,"",0,"normal",,,1,540,
        "Legs","14 Sep 2026, 18:05","14 Sep 2026, 19:10","Felt strong","Squat (Barbell)",,"Back-off",0,"normal",185,8,,,
        """

    @Test func importsAStrongExport() throws {
        let summary = try DataTransfer.importCSV(Data(Self.strong.utf8), into: context, timeZone: utc)

        #expect(summary.source == .strong)
        #expect(summary.workouts == .init(added: 2))
        #expect(summary.setsAdded == 9)
        #expect(summary.unreadableRows == 1)
        #expect(summary.unmatchedExerciseNames == ["Wrist Roller (Homemade)"])
        #expect(summary.customExercises == .init(added: 1))
        #expect(summary.recordsAdded > 0)

        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startedAt)]))
        let push = try #require(workouts.first)
        #expect(push.title == "Push, heavy")
        #expect(push.startedAt == Date(timeIntervalSince1970: 1_789_409_100))
        #expect(push.duration == 3_900)
        #expect(push.notes == "Good session")
        let custom = try #require(try context.fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(custom.name == "Wrist Roller (Homemade)")
        #expect(custom.tracking == .weightReps)
        #expect(
            push.orderedExercises.map(\.exerciseID) == ["bench-press", "overhead-press", "plank", custom.exerciseID])

        let bench = push.orderedExercises[0].orderedSets
        #expect(bench.map(\.weightKg) == [40, 80, 82.5])
        #expect(bench.map(\.isWarmUp) == [true, false, false])
        #expect(bench.map(\.rpe) == [nil, 8, 8.5])
        #expect(bench[1].notes == "Paused, first rep")
        #expect(bench.allSatisfy { $0.isCompleted && $0.completedAt == push.endedAt })
        let plank = try #require(push.orderedExercises[2].orderedSets.first)
        #expect(plank.seconds == 60)
        #expect(plank.weightKg == nil)
        #expect(plank.reps == nil)

        let pull = workouts[1]
        #expect(pull.orderedExercises.map(\.exerciseID) == ["deadlift", "pull-up", custom.exerciseID])
        #expect(pull.orderedExercises[1].orderedSets.first?.reps == 8)
    }

    @Test func importingTwiceAddsNothing() throws {
        try DataTransfer.importCSV(Data(Self.strong.utf8), into: context, timeZone: utc)
        let sets = try context.fetchCount(FetchDescriptor<LoggedSet>())
        let records = try context.fetchCount(FetchDescriptor<PersonalRecord>())

        let summary = try DataTransfer.importCSV(Data(Self.strong.utf8), into: context, timeZone: utc)

        #expect(summary.workouts == .init(skipped: 2))
        #expect(!summary.addedAnything)
        #expect(summary.unmatchedExerciseNames.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<LoggedSet>()) == sets)
        #expect(try context.fetchCount(FetchDescriptor<CustomExercise>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PersonalRecord>()) == records)
    }

    @Test func strongWeightsFollowTheUnitColumnThenTheFallback() throws {
        let pounds = try DataTransfer.importCSV(
            Data(Self.strong.utf8), into: context, fallbackUnits: .imperial, timeZone: utc)
        #expect(pounds.workouts.added == 2)
        let bench = try #require(
            try context.fetch(FetchDescriptor<LoggedExercise>()).first { $0.exerciseID == "bench-press" })
        #expect(abs(try #require(bench.orderedSets[1].weightKg) - 80 / Units.poundsPerKilogram) < 1e-9)

        // A newer layout: semicolons, a unit column, a distance, and seconds for the duration.
        let other = try TransmuteStore.makeContainer(.inMemory)
        let newer = """
            Workout #;Date;Workout Name;Duration (sec);Exercise Name;Set Order;Weight;Weight Unit;Reps;RPE;Distance;Distance Unit;Seconds;Notes;Workout Notes
            1;2026-09-14 18:05:00;Mixed;1800;Bench Press (Dumbbell);1;62,5;lbs;10;;0;;0;;
            1;2026-09-14 18:05:00;Mixed;1800;Running;1;0;;0;;2,5;km;900;;
            """
        let summary = try DataTransfer.importCSV(Data(newer.utf8), into: other.mainContext, timeZone: utc)
        #expect(summary.source == .strong)
        let workout = try #require(try other.mainContext.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.duration == 1_800)
        let press = workout.orderedExercises[0]
        #expect(press.exerciseID == "dumbbell-bench-press")
        #expect(abs(try #require(press.orderedSets.first?.weightKg) - 62.5 / Units.poundsPerKilogram) < 1e-9)
        let run = try #require(workout.orderedExercises[1].orderedSets.first)
        #expect(run.meters == 2_500)
        #expect(run.seconds == 900)
        #expect(summary.unmatchedExerciseNames == ["Running"])
        #expect(try other.mainContext.fetch(FetchDescriptor<CustomExercise>()).first?.tracking == .distanceTime)
    }

    @Test func importsAHevyExport() throws {
        let summary = try DataTransfer.importCSV(Data(Self.hevy.utf8), into: context, timeZone: utc)

        #expect(summary.source == .hevy)
        #expect(summary.workouts == .init(added: 1))
        #expect(summary.setsAdded == 5)
        #expect(summary.unreadableRows == 0)
        #expect(summary.unmatchedExerciseNames == ["Treadmill Run"])

        let workout = try #require(try context.fetch(FetchDescriptor<Workout>()).first)
        #expect(workout.title == "Legs")
        #expect(workout.startedAt == Date(timeIntervalSince1970: 1_789_409_100))
        #expect(workout.duration == 3_900)
        #expect(workout.notes == "Felt strong")
        let custom = try #require(try context.fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(custom.tracking == .distanceTime)
        // The squat comes back for a second block, and stays a second exercise.
        #expect(
            workout.orderedExercises.map(\.exerciseID)
                == ["back-squat", "romanian-deadlift", custom.exerciseID, "back-squat"])
        let squat = workout.orderedExercises[0]
        #expect(squat.notes == "Belt on")
        #expect(squat.orderedSets.map(\.isWarmUp) == [true, false])
        #expect(abs(try #require(squat.orderedSets[1].weightKg) - 225 / Units.poundsPerKilogram) < 1e-9)
        #expect(squat.orderedSets[1].rpe == 8)
        let run = try #require(workout.orderedExercises[2].orderedSets.first)
        #expect(abs(try #require(run.meters) - Units.metresPerMile) < 1e-9)
        #expect(run.seconds == 540)

        let again = try DataTransfer.importCSV(Data(Self.hevy.utf8), into: context, timeZone: utc)
        #expect(again.workouts == .init(skipped: 1))
        #expect(try context.fetchCount(FetchDescriptor<LoggedSet>()) == 5)
    }

    @Test func hevyKilogramsAreTakenAsTheyAre() throws {
        let metric = """
            title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe
            Upper,"3 Oct 2026, 07:00","3 Oct 2026, 07:45",,Bench Press (Barbell),,,0,normal,82.5,5,,,
            """
        try DataTransfer.importCSV(Data(metric.utf8), into: context, fallbackUnits: .imperial, timeZone: utc)
        let set = try #require(try context.fetch(FetchDescriptor<LoggedSet>()).first)
        #expect(set.weightKg == 82.5)
        #expect(set.exercise?.exerciseID == "bench-press")
    }

    @Test func otherFilesAreTurnedAway() throws {
        #expect(throws: DataTransferError.emptyFile) {
            try DataTransfer.importCSV(Data(), into: context)
        }
        #expect(throws: DataTransferError.unrecognizedCSV) {
            try DataTransfer.importCSV(Data("name,amount\nmilk,2\n".utf8), into: context)
        }
        #expect(throws: DataTransferError.unrecognizedCSV) {
            try DataTransfer.importCSV(Data([0xFF, 0xFE, 0x00]), into: context)
        }
        // Transmute's own CSV is for reading elsewhere; the backup is what comes back in.
        #expect(throws: DataTransferError.unrecognizedCSV) {
            try DataTransfer.importCSV(try DataTransfer.exportCSV(from: context), into: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 0)
    }

    @Test func matchesTheNamesOtherAppsUse() {
        let matcher = ExerciseNameMatcher(library: .bundled)
        let expected = [
            "Bench Press (Barbell)": "bench-press", "bench press (dumbbell)": "dumbbell-bench-press",
            "Squat (Barbell)": "back-squat", "Deadlift (Barbell)": "deadlift", "Pull Up": "pull-up",
            "Lat Pulldown (Cable)": "lat-pulldown", "Romanian Deadlift (Dumbbell)": "dumbbell-romanian-deadlift",
            "Shoulder Press (Machine)": "machine-shoulder-press", "RDL": "romanian-deadlift",
            "Farmer's Carry": "farmers-carry",
        ]
        for (name, id) in expected {
            #expect(matcher.match(name)?.id == id, "\(name)")
        }
        // Not a barbell bench press, so it isn't passed off as one.
        #expect(matcher.match("Bench Press (Smith Machine)") == nil)
        #expect(matcher.match("Deadlift (Kettlebell Swing Hybrid)") == nil)
        #expect(matcher.match("Something Nobody Does") == nil)
    }
}
