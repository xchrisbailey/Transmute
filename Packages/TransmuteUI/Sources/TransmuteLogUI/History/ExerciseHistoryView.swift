import Charts
import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Every logged set for one exercise, newest session first, with the estimated 1RM over
/// time for lifts that have one (shared with #16).
struct ExerciseHistoryView: View {
    let exerciseID: String
    let name: String
    let units: Units

    @Environment(\.modelContext) private var context
    @Query private var workouts: [Workout]

    private var entries: [WorkoutLog.ExerciseEntry] {
        _ = workouts.count  // Re-read when the log changes.
        return (try? WorkoutLog.history(of: exerciseID, in: context)) ?? []
    }

    var body: some View {
        let entries = entries
        let trend = entries.compactMap { entry in
            entry.estimatedOneRepMaxKg.map { (date: entry.workout.startedAt, kg: $0) }
        }
        let tracking = ExerciseLibrary.bundled.exercise(id: exerciseID)?.tracking ?? .weightReps
        List {
            if trend.count > 1 {
                Section {
                    Chart(trend, id: \.date) { point in
                        LineMark(
                            x: .value(Text(LogCopy.duration), point.date),
                            y: .value(Text(HistoryCopy.estimatedMaxTrend), units.displayWeight(kg: point.kg))
                        )
                        .foregroundStyle(Color.brand(\.magic))
                        PointMark(
                            x: .value(Text(LogCopy.duration), point.date),
                            y: .value(Text(HistoryCopy.estimatedMaxTrend), units.displayWeight(kg: point.kg))
                        )
                        .foregroundStyle(Color.brand(\.magic))
                    }
                    .chartYAxisLabel(units.weightSymbol)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 180)
                } header: {
                    Text(HistoryCopy.estimatedMaxTrend)
                }
            }
            ForEach(entries) { entry in
                Section {
                    SetTableHeader(tracking: tracking, units: units)
                    ForEach(Array(entry.sets.enumerated()), id: \.element.persistentModelID) { index, set in
                        PastSetRow(set: set, number: index + 1, tracking: tracking, units: units, gold: [])
                    }
                } header: {
                    Text(verbatim: entry.workout.startedAt.formatted(.dateTime.weekday().day().month().year()))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(verbatim: name))
    }
}
