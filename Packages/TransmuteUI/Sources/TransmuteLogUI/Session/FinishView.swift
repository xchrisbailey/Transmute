import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The summary after Finish: "The work is done. 18 sets, 8,420 kg moved.", the numbers, and a
/// plain Save. The workout is already stored when this shows; Save writes it to Health and
/// closes.
struct FinishView: View {
    let workout: Workout
    let summary: WorkoutSummary
    let units: Units
    let onSave: () -> Void

    @Environment(\.health) private var health
    @Query private var records: [PersonalRecord]
    @State private var healthStatus: HealthStatus = .idle

    enum HealthStatus {
        case idle, saving, saved, failed
    }

    var body: some View {
        List {
            Section {
                Text(headline)
                    .brandFont(.largeTitle)
                    .foregroundStyle(Color.brand(\.ink))
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }
            Section {
                figure(LogCopy.sets, "\(summary.sets)")
                if summary.volumeKg > 0 {
                    figure(LogCopy.volume, units.formatWeight(kg: summary.volumeKg))
                }
                figure(LogCopy.duration, Units.clock(seconds: summary.duration))
            }
            if !gold.isEmpty {
                Section {
                    ForEach(gold, id: \.first?.persistentModelID) { group in
                        if let record = group.first {
                            GoldRow(record: record, units: units)
                        }
                    }
                } header: {
                    Text(LogCopy.turnedToGold)
                }
            }
            switch healthStatus {
            case .saved:
                Label {
                    Text(LogCopy.savedToHealth)
                } icon: {
                    Image(systemName: "heart.fill")
                }
                .foregroundStyle(Color.brandText(\.subtext))
            case .failed:
                Text(LogCopy.healthFailed)
                    .foregroundStyle(Color.brandText(\.alert))
            case .idle, .saving:
                EmptyView()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await save() }
            } label: {
                Text(LogCopy.save)
                    .brandFont(.exerciseTitle)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand(\.magic))
            .disabled(healthStatus == .saving)
            .padding()
        }
    }

    /// Records this workout set, headline first per set.
    private var gold: [[PersonalRecord]] {
        let mine = records.filter { $0.set?.exercise?.workout === workout }
        return RecordBoard.gold(mine, since: workout.startedAt)
    }

    private var headline: LocalizedStringResource {
        summary.volumeKg > 0
            ? Copy.workDone(sets: summary.sets, moved: units.formatWeight(kg: summary.volumeKg))
            : LogCopy.workDone(sets: summary.sets)
    }

    private func figure(_ label: LocalizedStringResource, _ value: String) -> some View {
        LabeledContent {
            Text(verbatim: value)
                .brandNumberFont(size: 22, relativeTo: .title2)
                .foregroundStyle(Color.brand(\.ink))
        } label: {
            Text(label)
                .brandFont(.body)
        }
    }

    /// Writes the workout to Health once, then closes. A failure is shown but doesn't block.
    private func save() async {
        guard health.isAvailable, workout.healthKitWorkoutID == nil, healthStatus != .failed,
            let record = HealthWorkoutRecord(workout)
        else {
            onSave()
            return
        }
        healthStatus = .saving
        do {
            try await health.requestAccess(.workouts)
            workout.healthKitWorkoutID = try await health.save(record)
            try? workout.modelContext?.save()
            healthStatus = .saved
            onSave()
        } catch {
            healthStatus = .failed
        }
    }
}

/// One record from the finished workout, in gold: "Back squat · 5RM · 115 kg".
private struct GoldRow: View {
    let record: PersonalRecord
    let units: Units

    var body: some View {
        let name = ExerciseLibrary.bundled.exercise(id: record.exerciseID)?.name ?? record.exerciseID
        LabeledContent {
            Text(verbatim: RecordFormat.value(record.mark, units: units))
                .brandNumberFont(size: 17)
                .foregroundStyle(Color.brandText(\.gold))
        } label: {
            Label {
                Text(verbatim: "\(name) · \(String(localized: RecordFormat.label(record.mark, units: units)))")
            } icon: {
                Image(systemName: "medal.fill")
                    .foregroundStyle(Color.brand(\.gold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(RecordFormat.gold(record.mark, exercise: name, units: units)))
    }
}
