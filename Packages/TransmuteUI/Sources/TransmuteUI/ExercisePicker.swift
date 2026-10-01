import SwiftData
import SwiftUI
import TransmuteCore

#if !os(watchOS)
    /// Search the exercise library, including the user's custom exercises, and pick one.
    ///
    /// Feeds swapping an exercise in a plan (#10). Not on Apple Watch, which never edits plans. Filters start from `initialQuery`, so a caller
    /// can open it already narrowed, e.g. to tennis work for a speed day.
    public struct ExercisePicker: View {
        let library: ExerciseLibrary
        let onPick: (LibraryExercise) -> Void

        @Query(sort: \CustomExercise.name) private var customExercises: [CustomExercise]
        @State private var query: ExerciseQuery

        public init(
            library: ExerciseLibrary = .bundled, initialQuery: ExerciseQuery = ExerciseQuery(),
            onPick: @escaping (LibraryExercise) -> Void
        ) {
            self.library = library
            self.onPick = onPick
            _query = State(initialValue: initialQuery)
        }

        private var results: [LibraryExercise] {
            library.adding(customExercises.map(LibraryExercise.init)).search(query)
        }

        public var body: some View {
            List(results) { exercise in
                Button {
                    onPick(exercise)
                } label: {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query.text)
                }
            }
            .searchable(text: $query.text, prompt: Text(Labels.searchExercises))
            .toolbar {
                ToolbarItem {
                    filterMenu
                }
            }
        }

        private var filterMenu: some View {
            Menu {
                Picker(selection: singleSelection(\.categories)) {
                    Text(Labels.any).tag(ExerciseCategory?.none)
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(category.label).tag(ExerciseCategory?.some(category))
                    }
                } label: {
                    Text(Labels.category)
                }
                Picker(selection: singleSelection(\.equipment)) {
                    Text(Labels.any).tag(Equipment?.none)
                    ForEach(Equipment.allCases, id: \.self) { equipment in
                        Text(equipment.label).tag(Equipment?.some(equipment))
                    }
                } label: {
                    Text(Labels.equipment)
                }
                Picker(selection: singleSelection(\.sports)) {
                    Text(Labels.any).tag(String?.none)
                    ForEach(Labels.sportTags, id: \.self) { sport in
                        Text(Labels.sport(sport)).tag(String?.some(sport))
                    }
                } label: {
                    Text(Labels.sport)
                }
            } label: {
                Label {
                    Text(Labels.filters)
                } icon: {
                    Image(
                        systemName: isFiltered
                            ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .accessibilityValue(isFiltered ? Text(Labels.filtersOn) : Text(Labels.filtersOff))
        }

        private var isFiltered: Bool {
            !query.categories.isEmpty || !query.equipment.isEmpty || !query.sports.isEmpty
        }

        /// Binds a one-at-a-time menu choice to a set-valued filter.
        private func singleSelection<Value: Hashable>(_ keyPath: WritableKeyPath<ExerciseQuery, Set<Value>>) -> Binding<
            Value?
        > {
            Binding {
                query[keyPath: keyPath].first
            } set: { value in
                query[keyPath: keyPath] = value.map { [$0] } ?? []
            }
        }
    }

#endif

/// One exercise in a list: name, then category and what it needs.
public struct ExerciseRow: View {
    let exercise: LibraryExercise

    public init(exercise: LibraryExercise) {
        self.exercise = exercise
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: exercise.name)
                .brandFont(.body)
                .foregroundStyle(Color.brand(\.ink))
            Text(verbatim: detail)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var detail: String {
        let category = String(localized: exercise.category.label)
        let equipment = exercise.equipment.map { group in
            group.map { String(localized: $0.label) }.joined(separator: " / ")
        }
        return ([category] + equipment).joined(separator: " · ")
    }
}

#if !os(watchOS)
    #Preview {
        NavigationStack {
            ExercisePicker(initialQuery: ExerciseQuery(sports: ["tennis"])) { _ in }
                .navigationTitle(Text(verbatim: "Swap exercise"))
        }
        .modelContainer(try! SampleData.previewContainer())  // swiftlint:disable:this force_try
    }
#endif
