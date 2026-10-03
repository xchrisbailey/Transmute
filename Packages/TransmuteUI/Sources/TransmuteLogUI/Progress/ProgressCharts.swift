import Charts
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Estimated 1RM over time for one of the plan's key lifts, with records as gold points.
struct MaxChartCard: View {
    let lifts: [String]
    let workouts: [Workout]
    let records: [PersonalRecord]
    let units: Units

    @State private var picked: String?
    let library = ExerciseLibrary.bundled

    private var lift: String? {
        picked.flatMap { lifts.contains($0) ? $0 : nil } ?? lifts.first
    }

    var body: some View {
        if let lift {
            let points = ProgressStats.maxTrend(of: lift, workouts: workouts, records: records)
            ProgressCard(title: ProgressCopy.estimatedMax) {
                if lifts.count > 1 {
                    Picker(selection: Binding(get: { lift }, set: { picked = $0 })) {
                        ForEach(lifts, id: \.self) { id in
                            Text(verbatim: library.exercise(id: id)?.name ?? id).tag(id)
                        }
                    } label: {
                        Text(ProgressCopy.lift)
                    }
                    .labelsHidden()
                }
                Chart(points) { point in
                    LineMark(
                        x: .value(Text(ProgressCopy.date), point.date),
                        y: .value(Text(ProgressCopy.estimatedMax), units.displayWeight(kg: point.kg))
                    )
                    .foregroundStyle(Color.brand(\.magic))
                    PointMark(
                        x: .value(Text(ProgressCopy.date), point.date),
                        y: .value(Text(ProgressCopy.estimatedMax), units.displayWeight(kg: point.kg))
                    )
                    // Records are gold and a different shape, so colour isn't the only signal.
                    .foregroundStyle(point.isRecord ? Color.brand(\.gold) : Color.brand(\.magic))
                    .symbol(point.isRecord ? .diamond : .circle)
                    .symbolSize(point.isRecord ? 90 : 30)
                }
                .chartYAxisLabel(units.weightSymbol)
                .chartYScale(domain: .automatic(includesZero: false))
                .numberAxes()
                .frame(height: 200)
                Text(ProgressCopy.estimatedMaxHelp)
                    .font(.caption)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
    }
}

/// Weight lifted per week, stacked by kind of training or by muscle.
struct VolumeChartCard: View {
    let workouts: [Workout]
    let units: Units

    @State private var grouping = ProgressStats.VolumeGrouping.category

    /// One bar segment, with its legend name resolved.
    private struct Segment: Identifiable {
        let weekStart: Date
        let group: String
        let value: Double
        var id: String { "\(weekStart.timeIntervalSince1970)-\(group)" }
    }

    private var segments: [Segment] {
        let weeks = ProgressStats.weeklyVolume(workouts, by: grouping)
        // Keep the legend readable: the five biggest groups, and the rest together.
        var totals: [String: Double] = [:]
        for slice in weeks.flatMap(\.slices) {
            totals[slice.group, default: 0] += slice.kg
        }
        let top = Set(totals.sorted { $0.value > $1.value }.prefix(5).map(\.key))
        let other = String(localized: ProgressCopy.other)
        return weeks.flatMap { week in
            var merged: [String: Double] = [:]
            for slice in week.slices {
                merged[top.contains(slice.group) ? name(of: slice.group) : other, default: 0] += slice.kg
            }
            return merged.sorted { $0.key < $1.key }.map {
                Segment(weekStart: week.weekStart, group: $0.key, value: units.displayWeight(kg: $0.value))
            }
        }
    }

    private func name(of group: String) -> String {
        if group == ProgressStats.otherGroup { return String(localized: ProgressCopy.other) }
        switch grouping {
        case .category: return ExerciseCategory(rawValue: group).map { String(localized: $0.label) } ?? group
        case .muscle: return Muscle(rawValue: group).map { String(localized: $0.label) } ?? group
        }
    }

    var body: some View {
        let segments = segments
        if !segments.isEmpty {
            ProgressCard(title: ProgressCopy.weeklyVolume) {
                Picker(selection: $grouping) {
                    Text(ProgressCopy.byCategory).tag(ProgressStats.VolumeGrouping.category)
                    Text(ProgressCopy.byMuscle).tag(ProgressStats.VolumeGrouping.muscle)
                } label: {
                    Text(ProgressCopy.split)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Chart(segments) { segment in
                    BarMark(
                        x: .value(Text(ProgressCopy.week), segment.weekStart, unit: .weekOfYear),
                        y: .value(Text(ProgressCopy.weeklyVolume), segment.value)
                    )
                    .foregroundStyle(by: .value(Text(ProgressCopy.split), segment.group))
                }
                .chartForegroundStyleScale(range: [
                    Color.brand(\.magic), Color.brand(\.now), Color.brand(\.done), Color.brand(\.sparklePink),
                    Color.brand(\.sparkleLavender), Color.brand(\.overlay1),
                ])
                .chartYAxisLabel(units.weightSymbol)
                .numberAxes()
                .frame(height: 220)
            }
        }
    }
}

/// Bodyweight entries, with a 7-day average through them.
struct BodyweightChartCard: View {
    let points: [ProgressStats.BodyweightPoint]
    let units: Units

    var body: some View {
        if points.count > 1 {
            ProgressCard(title: ProgressCopy.bodyweight) {
                Chart(points) { point in
                    PointMark(
                        x: .value(Text(ProgressCopy.date), point.date),
                        y: .value(Text(ProgressCopy.bodyweight), units.displayWeight(kg: point.kg))
                    )
                    .foregroundStyle(Color.brand(\.overlay1))
                    .symbolSize(20)
                    LineMark(
                        x: .value(Text(ProgressCopy.date), point.date),
                        y: .value(Text(ProgressCopy.trend), units.displayWeight(kg: point.trendKg))
                    )
                    .foregroundStyle(Color.brand(\.magic))
                    .interpolationMethod(.monotone)
                }
                .chartYAxisLabel(units.weightSymbol)
                .chartYScale(domain: .automatic(includesZero: false))
                .numberAxes()
                .frame(height: 180)
                Text(ProgressCopy.trend)
                    .font(.caption)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
    }
}

/// One conditioning exercise over time: rounds, pace, longest effort or most reps.
struct ConditioningChartCard: View {
    let series: ProgressStats.ConditioningSeries

    private var measure: LocalizedStringResource {
        switch series.metric {
        case .rounds: ProgressCopy.rounds
        case .pace: ProgressCopy.pace
        case .longestTime: ProgressCopy.longestTime
        case .reps: ProgressCopy.mostReps
        }
    }

    var body: some View {
        ProgressCard(title: LocalizedStringResource(stringLiteral: series.name)) {
            Chart(series.points) { point in
                LineMark(
                    x: .value(Text(ProgressCopy.date), point.date), y: .value(Text(measure), point.value)
                )
                .foregroundStyle(Color.brand(\.now))
                PointMark(
                    x: .value(Text(ProgressCopy.date), point.date), y: .value(Text(measure), point.value)
                )
                .foregroundStyle(Color.brand(\.now))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .numberAxes()
            .frame(height: 150)
            Text(measure)
                .font(.caption)
                .foregroundStyle(Color.brandText(\.subtext))
        }
    }
}

/// Sessions planned and done in each week of the plan so far.
struct AdherenceChartCard: View {
    let weeks: [ProgressStats.WeekAdherence]

    var body: some View {
        ProgressCard(title: ProgressCopy.adherence) {
            Chart(weeks) { week in
                BarMark(
                    x: .value(Text(ProgressCopy.week), String(localized: ProgressCopy.planWeek(week.week))),
                    y: .value(Text(ProgressCopy.planned), week.planned)
                )
                .foregroundStyle(Color.brand(\.surface1))
                BarMark(
                    x: .value(Text(ProgressCopy.week), String(localized: ProgressCopy.planWeek(week.week))),
                    y: .value(Text(ProgressCopy.done), week.done), width: .ratio(0.5)
                )
                .foregroundStyle(week.isHit ? Color.brand(\.done) : Color.brand(\.magic))
                .annotation(position: .top) {
                    Text(verbatim: "\(week.done)/\(week.planned)")
                        .brandNumberFont(size: 11, relativeTo: .caption2)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 160)
        }
    }
}

extension View {
    /// Geist Mono on a chart's axis numbers, like every other number in the app.
    func numberAxes() -> some View {
        chartYAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.brandNumber(size: 11, relativeTo: .caption2))
            }
        }
    }
}
