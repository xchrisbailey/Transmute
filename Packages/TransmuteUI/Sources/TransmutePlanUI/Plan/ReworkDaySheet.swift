import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// "Rework this day" (#10): a short note in, a reworked day out, shown as a before and after to
/// use or throw away. Nothing changes until "Use this".
public struct ReworkDaySheet: View {
    let day: PlanDay
    let plan: Plan
    let profile: Profile
    let service: any IntelligenceService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var note = ""
    @State private var result: TemplateDay?
    @State private var error: IntelligenceError?
    @State private var isWorking = false
    @State private var status: IntelligenceStatus
    let library = ExerciseLibrary.bundled

    public init(day: PlanDay, plan: Plan, profile: Profile, service: any IntelligenceService) {
        self.day = day
        self.plan = plan
        self.profile = profile
        self.service = service
        _status = State(initialValue: IntelligenceStatus(service: service))
    }

    private var units: Units {
        Units(system: profile.unitSystem)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $note, axis: .vertical) {
                        Text(PlanCopy.reworkPrompt)
                    }
                    .lineLimit(2...4)
                    IntelligenceNotice(availability: status.availability)
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text(PlanCopy.reworking)
                                .foregroundStyle(Color.brandText(\.magic))
                        }
                        .accessibilityElement(children: .combine)
                    } else if result == nil {
                        Button {
                            Task { await rework() }
                        } label: {
                            Text(PlanCopy.reworkGo)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand(\.magic))
                        .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty || !status.availability.canGenerate)
                    }
                    if let error {
                        Text(error.message)
                            .foregroundStyle(Color.brandText(\.alert))
                    }
                }
                if let result {
                    diff(result)
                    Section {
                        Button {
                            result.replaceExercises(of: day, in: context)
                            dismiss()
                        } label: {
                            Text(PlanCopy.useThis)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand(\.magic))
                        Button {
                            self.result = nil
                        } label: {
                            Text(PlanCopy.keepOriginal)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand(\.base))
            .navigationTitle(Text(Copy.reworkDay))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(ProfileCopy.cancel)
                    }
                }
            }
            .task { await status.watch() }
        }
    }

    /// Before and after, each line marked kept, added or removed in words and icons (#22).
    private func diff(_ result: TemplateDay) -> some View {
        let before = day.orderedExercises.map(\.exerciseID)
        let after = result.exercises.map(\.exerciseID)
        return Group {
            Section {
                ForEach(Array(result.exercises.enumerated()), id: \.offset) { _, exercise in
                    let kept = before.contains(exercise.exerciseID)
                    DiffRow(
                        name: name(exercise.exerciseID), detail: SetTargets(exercise.sets).summary(units: units),
                        marker: kept ? PlanCopy.kept : PlanCopy.added, icon: kept ? "equal" : "plus",
                        tint: kept ? Color.brandText(\.subtext) : Color.brandText(\.done))
                }
            } header: {
                Text(PlanCopy.after)
            } footer: {
                if !result.why.isEmpty {
                    Text(verbatim: result.why)
                }
            }
            let removed = before.filter { !after.contains($0) }
            if !removed.isEmpty {
                Section {
                    ForEach(removed, id: \.self) { id in
                        DiffRow(
                            name: name(id), detail: nil, marker: PlanCopy.removed, icon: "minus",
                            tint: Color.brandText(\.alert))
                    }
                } header: {
                    Text(PlanCopy.before)
                }
            }
        }
    }

    private func name(_ id: String) -> String {
        library.exercise(id: id)?.name ?? id
    }

    private func rework() async {
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            result = try await PlanBrewer(service: service).rework(
                ReworkTarget(day, in: plan), note: note, brief: TrainingBrief(profile), units: units.system)
        } catch let failure as IntelligenceError {
            error = failure
        } catch {
            self.error = .failed(detail: "\(error)")
        }
    }
}

struct DiffRow: View {
    let name: String
    let detail: String?
    let marker: LocalizedStringResource
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(verbatim: name)
                    .brandFont(.body)
                if let detail {
                    Text(verbatim: detail)
                        .brandNumberFont(size: 14)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            Spacer()
            Text(marker)
                .brandFont(.label)
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}
