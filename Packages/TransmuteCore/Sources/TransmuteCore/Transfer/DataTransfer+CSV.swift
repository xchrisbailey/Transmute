import Foundation
import SwiftData

extension DataTransfer {
    /// Every logged set as CSV, one row per set, oldest workout first. See `WorkoutCSV` for the
    /// columns. Custom exercises in the store are named too.
    public static func exportCSV(from context: ModelContext, library: ExerciseLibrary = .bundled) throws -> Data {
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        return Data(WorkoutCSV.text(for: workouts, library: try library.addingCustomExercises(in: context)).utf8)
    }

    /// Imports workouts from a Strong or Hevy CSV export and saves. The app is told apart by the
    /// header row.
    ///
    /// Exercise names are matched to the library by name and alias; a name with no match
    /// becomes a custom exercise and is listed in the summary. A workout with the same start
    /// time and title as one in the store is skipped, so importing a file twice adds nothing.
    /// Records are recomputed for the exercises that gained sets.
    ///
    /// - Parameters:
    ///   - fallbackUnits: The units to assume where the file doesn't say. Hevy always says;
    ///     older Strong exports don't.
    ///   - timeZone: The zone the file's wall-clock times are in.
    @discardableResult
    public static func importCSV(
        _ data: Data, into context: ModelContext, fallbackUnits: UnitSystem = .metric,
        timeZone: TimeZone = .current, library: ExerciseLibrary = .bundled
    ) throws -> ImportSummary {
        guard !data.isEmpty else { throw DataTransferError.emptyFile }
        guard let text = String(data: data, encoding: .utf8), let table = CSVTable(text) else {
            throw DataTransferError.unrecognizedCSV
        }
        let reader = WorkoutCSVReader(table: table, fallbackUnits: fallbackUnits, timeZone: timeZone)
        guard let file = reader.read() else { throw DataTransferError.unrecognizedCSV }
        return try rollingBack(context) {
            var merge = WorkoutCSVMerge(
                file: file, context: context, library: try library.addingCustomExercises(in: context))
            return try merge.run()
        }
    }
}
