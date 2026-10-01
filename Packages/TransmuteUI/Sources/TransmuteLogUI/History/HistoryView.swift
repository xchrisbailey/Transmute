import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The workout log (#14): newest first, grouped by week, with search and filters. Each row
/// says the day, how long, how many sets and how much was moved, and wears a medal when
/// something turned to gold.
public struct HistoryView: View {
    let profile: Profile
    /// The active plan, for the "This plan" filter.
    let plan: Plan?

    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var records: [PersonalRecord]
    @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
    @State private var filter = WorkoutLog.Filter()
    @State private var range: DateRange = .any

    public init(profile: Profile, plan: Plan?) {
        self.profile = profile
        self.plan = plan
    }

    enum DateRange: CaseIterable {
        case any, month, quarter, year

        var label: LocalizedStringResource {
            switch self {
            case .any: HistoryCopy.anyTime
            case .month: HistoryCopy.lastMonth
            case .quarter: HistoryCopy.lastQuarter
            case .year: HistoryCopy.lastYear
            }
        }

        func interval(now: Date = .now) -> DateInterval? {
            let days: Double? =
                switch self {
                case .any: nil
                case .month: 28
                case .quarter: 91
                case .year: 365
                }
            return days.map { DateInterval(start: now.addingTimeInterval(-$0 * 86_400), end: now) }
        }
    }

    private var library: ExerciseLibrary {
        ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
    }

    private var units: Units {
        Units(system: profile.unitSystem)
    }

    private var matching: [Workout] {
        var filter = filter
        filter.dates = range.interval()
        return WorkoutLog.workouts(workouts, matching: filter, library: library)
    }

    /// Workouts with at least one record, for the gold medal.
    private var goldWorkouts: Set<PersistentIdentifier> {
        Set(records.compactMap { $0.set?.exercise?.workout?.persistentModelID })
    }

    public var body: some View {
        let weeks = WorkoutLog.weeks(matching)
        let gold = goldWorkouts
        List {
            ForEach(weeks) { week in
                Section {
                    ForEach(week.workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout, profile: profile)
                        } label: {
                            WorkoutRow(
                                workout: workout, units: units, hasGold: gold.contains(workout.persistentModelID))
                        }
                    }
                } header: {
                    Text(HistoryCopy.weekOf(week.start.formatted(.dateTime.month(.abbreviated).day())))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .overlay {
            if weeks.isEmpty {
                if workouts.contains(where: { $0.endedAt != nil }) {
                    ContentUnavailableView {
                        Text(HistoryCopy.noMatches)
                    } actions: {
                        Button {
                            filter = WorkoutLog.Filter()
                            range = .any
                        } label: {
                            Text(HistoryCopy.clearFilters)
                        }
                    }
                } else {
                    ContentUnavailableView {
                        Image(systemName: "flask")
                            .foregroundStyle(Color.brand(\.magic))
                    } description: {
                        Text(Copy.emptyLog)
                            .brandFont(.body)
                    }
                }
            }
        }
        .searchable(text: $filter.text, prompt: Text(HistoryCopy.search))
        .navigationTitle(Text(HistoryCopy.title))
        .toolbar {
            ToolbarItem {
                filterMenu
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            if let plan {
                Picker(selection: $filter.planID) {
                    Text(HistoryCopy.allPlans).tag(UUID?.none)
                    Text(HistoryCopy.thisPlan).tag(UUID?.some(plan.id))
                } label: {
                    Text(HistoryCopy.thisPlan)
                }
            }
            Picker(selection: $range) {
                ForEach(DateRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            } label: {
                Text(HistoryCopy.anyTime)
            }
        } label: {
            Label {
                Text(HistoryCopy.filters)
            } icon: {
                Image(
                    systemName: filter.planID == nil && range == .any
                        ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
    }
}

/// "Lower A", its date, and "52:10 · 18 sets · 8,420 kg", with a gold medal for records.
struct WorkoutRow: View {
    let workout: Workout
    let units: Units
    let hasGold: Bool

    var body: some View {
        let summary = WorkoutSummary(workout)
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.startedAt, format: .dateTime.weekday(.wide).day().month())
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                Text(verbatim: workout.title)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(Color.brand(\.ink))
                Text(verbatim: line(summary))
                    .brandNumberFont(size: 15)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            Spacer()
            if hasGold {
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color.brand(\.gold))
                    .accessibilityLabel(Text(LogCopy.turnedToGold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func line(_ summary: WorkoutSummary) -> String {
        var parts = [Units.clock(seconds: summary.duration), String(localized: HistoryCopy.setsCount(summary.sets))]
        if summary.volumeKg > 0 {
            parts.append(units.formatWeight(kg: summary.volumeKg))
        }
        return parts.joined(separator: " · ")
    }
}
