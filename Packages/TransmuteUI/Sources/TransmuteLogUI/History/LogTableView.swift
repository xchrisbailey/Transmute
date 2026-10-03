import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// One line of the Mac's log table: a finished workout with the figures its columns sort by.
struct LogTableRow: Identifiable {
    let workout: Workout
    let date: Date
    let title: String
    let duration: TimeInterval
    let sets: Int
    let volumeKg: Double
    /// Personal records set in this workout.
    let records: Int

    var id: PersistentIdentifier { workout.persistentModelID }

    init(_ workout: Workout, records: Int) {
        let summary = WorkoutSummary(workout)
        self.workout = workout
        date = workout.startedAt
        title = workout.title
        duration = summary.duration
        sets = summary.sets
        volumeKg = summary.volumeKg
        self.records = records
    }

    /// A row for each workout, counting the records that belong to it.
    static func rows(_ workouts: [Workout], records: [PersonalRecord]) -> [LogTableRow] {
        var counts: [PersistentIdentifier: Int] = [:]
        for record in records {
            if let id = record.set?.exercise?.workout?.persistentModelID {
                counts[id, default: 0] += 1
            }
        }
        return workouts.map { LogTableRow($0, records: counts[$0.persistentModelID] ?? 0) }
    }
}

#if os(macOS)
    /// The workout log on the Mac (#17): a table with sortable columns, the same search and
    /// filters as the iPhone's log, and an inspector for the selected workout. Edits and deletes
    /// go through `WorkoutLog`, so records are rebuilt exactly as they are on the iPhone.
    public struct LogTableView: View {
        let profile: Profile
        /// The active plan, for the "This plan" filter.
        let plan: Plan?
        /// Focus for the search field, so a Find command can put the cursor there.
        let searchFocus: FocusState<Bool>.Binding?
        /// Set from outside to the `Workout.id` to select, as Open workout and Spotlight do (#19).
        @Binding var opening: UUID?

        @Environment(\.modelContext) private var context
        @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
        @Query private var records: [PersonalRecord]
        @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
        @State private var filter = WorkoutLog.Filter()
        @State private var range: HistoryView.DateRange = .any
        @State private var sortOrder = [KeyPathComparator(\LogTableRow.date, order: .reverse)]
        @State private var selection: LogTableRow.ID?
        @SceneStorage("log.showsInspector") private var showsInspector = true
        @State private var deleting: Workout?
        @State private var healthKeepsCopy = false

        public init(
            profile: Profile, plan: Plan?, searchFocus: FocusState<Bool>.Binding? = nil,
            opening: Binding<UUID?> = .constant(nil)
        ) {
            self.profile = profile
            self.plan = plan
            self.searchFocus = searchFocus
            _opening = opening
        }

        private var library: ExerciseLibrary {
            ExerciseLibrary.bundled.adding(customExercises.map(LibraryExercise.init))
        }

        private var units: Units {
            Units(profile)
        }

        private var rows: [LogTableRow] {
            var filter = filter
            filter.dates = range.interval()
            let matching = WorkoutLog.workouts(workouts, matching: filter, library: library)
            return LogTableRow.rows(matching, records: records).sorted(using: sortOrder)
        }

        public var body: some View {
            let rows = rows
            let selected = rows.first { $0.id == selection }?.workout
            Table(rows, selection: $selection, sortOrder: $sortOrder) {
                columns
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand(\.base))
            .contextMenu(forSelectionType: LogTableRow.ID.self) { ids in
                if let workout = rows.first(where: { ids.contains($0.id) })?.workout {
                    Button(role: .destructive) {
                        deleting = workout
                    } label: {
                        Text(HistoryCopy.delete)
                    }
                }
            } primaryAction: { _ in
                showsInspector = true
            }
            .onDeleteCommand {
                deleting = selected
            }
            .onKeyPress(.return) {
                showsInspector.toggle()
                return .handled
            }
            .overlay {
                if rows.isEmpty { emptyState }
            }
            .searchable(text: $filter.text, prompt: Text(HistoryCopy.search))
            .modifier(SearchFocus(focus: searchFocus))
            .navigationTitle(Text(HistoryCopy.title))
            .toolbar { toolbar }
            .inspector(isPresented: $showsInspector) {
                inspector(selected)
                    .inspectorColumnWidth(min: 280, ideal: 340, max: 520)
            }
            .confirmationDialog(
                Text(deleteQuestion), isPresented: isConfirmingDelete, titleVisibility: .visible, presenting: deleting
            ) { workout in
                Button(role: .destructive) {
                    delete(workout)
                } label: {
                    Text(HistoryCopy.delete)
                }
            }
            .alert(Text(HistoryCopy.healthDeleteFailed), isPresented: $healthKeepsCopy) {}
            .onChange(of: opening, initial: true) { _, id in
                guard let id else { return }
                opening = nil
                // A workout that's since been deleted leaves the log as it is.
                guard let workout = workouts.first(where: { $0.id == id && $0.endedAt != nil }) else { return }
                // Filters could be hiding it.
                filter = WorkoutLog.Filter()
                range = .any
                selection = workout.persistentModelID
                showsInspector = true
            }
        }

        /// The same plain question the iPhone asks before deleting a workout.
        private var deleteQuestion: LocalizedStringResource {
            Copy.deleteWorkout(
                deleting?.title ?? "", date: (deleting?.startedAt ?? .now).formatted(.dateTime.month().day()))
        }

        private var isConfirmingDelete: Binding<Bool> {
            Binding {
                deleting != nil
            } set: { isShown in
                if !isShown { deleting = nil }
            }
        }

        @TableColumnBuilder<LogTableRow, KeyPathComparator<LogTableRow>>
        private var columns: some TableColumnContent<LogTableRow, KeyPathComparator<LogTableRow>> {
            TableColumn(Text(HistoryCopy.columnDate), value: \.date) { row in
                Text(row.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
            }
            .width(min: 124, ideal: 146)
            TableColumn(Text(HistoryCopy.columnWorkout), value: \.title) { row in
                Text(verbatim: row.title)
            }
            .width(min: 120, ideal: 200)
            TableColumn(Text(HistoryCopy.columnDuration), value: \.duration) { row in
                Text(verbatim: Units.clock(seconds: row.duration))
                    .brandNumberFont(size: 13)
            }
            .width(min: 64, ideal: 72)
            TableColumn(Text(HistoryCopy.columnSets), value: \.sets) { row in
                Text(verbatim: row.sets.formatted())
                    .brandNumberFont(size: 13)
            }
            .width(min: 40, ideal: 48)
            TableColumn(Text(HistoryCopy.columnVolume), value: \.volumeKg) { row in
                Text(verbatim: row.volumeKg > 0 ? units.formatWeight(kg: row.volumeKg) : "–")
                    .brandNumberFont(size: 13)
            }
            .width(min: 84, ideal: 108)
            TableColumn(Text(HistoryCopy.columnRecords), value: \.records) { row in
                RecordsCell(records: row.records)
            }
            .width(min: 60, ideal: 68)
        }

        @ToolbarContentBuilder private var toolbar: some ToolbarContent {
            ToolbarItem {
                LogFilterMenu(filter: $filter, range: $range, plan: plan)
            }
            ToolbarItem {
                Button {
                    showsInspector.toggle()
                } label: {
                    Label {
                        Text(HistoryCopy.details)
                    } icon: {
                        Image(systemName: "sidebar.trailing")
                    }
                }
            }
        }

        @ViewBuilder private var emptyState: some View {
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

        @ViewBuilder private func inspector(_ workout: Workout?) -> some View {
            if let workout {
                NavigationStack {
                    WorkoutDetailView(workout: workout, profile: profile) { deleting = workout }
                }
                .id(workout.persistentModelID)
            } else {
                ContentUnavailableView {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(Color.brandText(\.subtext))
                } description: {
                    Text(HistoryCopy.noSelection)
                        .brandFont(.body)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.brand(\.base))
            }
        }

        /// Deletes through `WorkoutLog`, which rebuilds the records. The Mac has no Health, so a
        /// workout that was saved there from the iPhone is left for the person to remove.
        private func delete(_ workout: Workout) {
            // The inspector lets go of the workout before it's gone.
            if selection == workout.persistentModelID { selection = nil }
            deleting = nil
            let healthID = try? WorkoutLog.delete(workout, in: context, library: library)
            healthKeepsCopy = healthID != nil
        }
    }

    /// A medal and a count when the workout set records, so gold isn't told by colour alone.
    private struct RecordsCell: View {
        let records: Int

        var body: some View {
            Group {
                if records > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "medal.fill")
                            .foregroundStyle(Color.brand(\.gold))
                        Text(verbatim: records.formatted())
                            .brandNumberFont(size: 13)
                    }
                } else {
                    Text(verbatim: "–")
                        .brandNumberFont(size: 13)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(records > 0 ? HistoryCopy.recordsCount(records) : HistoryCopy.noRecords))
        }
    }

    /// Ties the search field to a focus binding when the host passed one.
    private struct SearchFocus: ViewModifier {
        let focus: FocusState<Bool>.Binding?

        func body(content: Content) -> some View {
            if let focus {
                content.searchFocused(focus)
            } else {
                content
            }
        }
    }

    #Preview {
        let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
        // swiftlint:disable:next force_try
        let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
        return NavigationStack {
            LogTableView(profile: profile, plan: nil)
        }
        .modelContainer(container)
    }
#endif
