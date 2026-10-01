import SwiftData
import SwiftUI
import TransmuteCore

/// Personal records (#13): what turned to gold since a date, such as the plan's start, and the
/// current bests for every exercise. Gold marks records here and nowhere else.
///
///     RecordsView(since: plan.startDate, units: Units(system: profile.unitSystem))
public struct RecordsView: View {
    let since: Date?
    let units: Units
    let library: ExerciseLibrary

    @Query(sort: \PersonalRecord.date, order: .reverse) private var records: [PersonalRecord]
    @Query private var customExercises: [CustomExercise]

    /// - Parameter since: the start of "Turned to gold this block". `nil` leaves the section out.
    public init(since: Date?, units: Units, library: ExerciseLibrary = .bundled) {
        self.since = since
        self.units = units
        self.library = library
    }

    private func name(of exerciseID: String) -> String {
        library.exercise(id: exerciseID)?.name
            ?? customExercises.first { $0.exerciseID == exerciseID }?.name
            ?? exerciseID
    }

    public var body: some View {
        let bests = RecordBoard.bests(records)
        let exercises = bests.keys.sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }
        List {
            if let since, !records.isEmpty {
                Section {
                    let gold = RecordBoard.gold(records, since: since)
                    if gold.isEmpty {
                        Text(RecordCopy.noGoldThisBlock)
                            .brandFont(.body)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    ForEach(gold, id: \.first?.persistentModelID) { group in
                        GoldRow(records: group, exercise: name(of: group.first?.exerciseID ?? ""), units: units)
                    }
                } header: {
                    Text(RecordCopy.goldThisBlock)
                }
            }
            ForEach(exercises, id: \.self) { exerciseID in
                Section {
                    ForEach(bests[exerciseID] ?? []) { record in
                        BestRow(record: record, units: units)
                    }
                } header: {
                    Text(verbatim: name(of: exerciseID))
                }
            }
        }
        .overlay {
            if records.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text(RecordCopy.title)
                    } icon: {
                        Image(systemName: "medal")
                    }
                } description: {
                    Text(RecordCopy.empty)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(RecordCopy.title))
    }
}

/// One set that turned to gold: its headline record, and any others it set alongside.
private struct GoldRow: View {
    let records: [PersonalRecord]
    let exercise: String
    let units: Units

    var body: some View {
        if let headline = records.first {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color.brand(\.gold))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: exercise)
                        .brandFont(.body)
                    HStack(alignment: .firstTextBaseline) {
                        Text(RecordFormat.label(headline.mark, units: units))
                            .brandFont(.label)
                        Text(verbatim: RecordFormat.value(headline.mark, units: units))
                            .brandNumberFont(size: 15)
                            .foregroundStyle(Color.brandText(\.gold))
                    }
                    if records.count > 1 {
                        let others = records.dropFirst().map {
                            String(localized: RecordFormat.label($0.mark, units: units))
                        }
                        Text(RecordCopy.also(others.formatted(.list(type: .and))))
                            .brandFont(.label)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                }
                Spacer(minLength: 0)
                Text(headline.date, format: .dateTime.day().month())
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(RecordFormat.gold(headline.mark, exercise: exercise, units: units)))
            .accessibilityValue(Text(headline.date, format: .dateTime.day().month()))
        }
    }
}

/// A current best in an exercise's table, e.g. "5RM   115 kg".
private struct BestRow: View {
    let record: PersonalRecord
    let units: Units

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(RecordFormat.label(record.mark, units: units))
                .brandFont(.body)
            Spacer()
            Text(verbatim: RecordFormat.value(record.mark, units: units))
                .brandNumberFont(size: 17)
            Text(record.date, format: .dateTime.day().month().year())
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    try? RecordBook(context: container.mainContext).recomputeAll()
    return NavigationStack {
        RecordsView(since: .now.addingTimeInterval(-14 * 86_400), units: Units(system: .metric))
    }
    .modelContainer(container)
}
