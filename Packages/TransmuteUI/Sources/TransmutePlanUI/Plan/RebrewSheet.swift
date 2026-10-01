import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// Rebrew (#10): regenerate the plan from a chosen week on. Logged days always stay; hand-edited
/// days stay unless the person says otherwise.
struct RebrewSheet: View {
    let plan: Plan
    let profile: Profile
    let service: any IntelligenceService

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var fromWeek: Int
    @State private var keepEdits = true
    @State private var isWorking = false
    @State private var progress: LocalizedStringResource?
    @State private var error: IntelligenceError?
    @State private var status: IntelligenceStatus
    @State private var task: Task<Void, Never>?

    init(plan: Plan, profile: Profile, service: any IntelligenceService, currentWeek: Int) {
        self.plan = plan
        self.profile = profile
        self.service = service
        _fromWeek = State(initialValue: currentWeek)
        _status = State(initialValue: IntelligenceStatus(service: service))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $fromWeek, in: 1...max(1, plan.weekCount)) {
                        Text(PlanCopy.rebrewFrom(fromWeek))
                    }
                    Toggle(isOn: $keepEdits) {
                        Text(PlanCopy.keepEdits)
                    }
                } footer: {
                    Text(PlanCopy.rebrewNote)
                }
                Section {
                    IntelligenceNotice(availability: status.availability)
                    if isWorking {
                        HStack {
                            ProgressView()
                            Text(progress ?? PlanCopy.rebrewing(fromWeek))
                                .foregroundStyle(Color.brandText(\.magic))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.updatesFrequently)
                    } else {
                        Button {
                            start()
                        } label: {
                            Text(Copy.rebrew)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.brand(\.magic))
                        .disabled(!status.availability.canGenerate)
                    }
                    if let error {
                        Text(error.message)
                            .foregroundStyle(Color.brandText(\.alert))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.brand(\.base))
            .navigationTitle(Text(Copy.rebrew))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        task?.cancel()
                        dismiss()
                    } label: {
                        Text(ProfileCopy.cancel)
                    }
                }
            }
            .task { await status.watch() }
        }
    }

    private func start() {
        isWorking = true
        error = nil
        var brief = TrainingBrief(profile)
        brief.schedule.weeks = plan.weekCount
        let units = Units(system: profile.unitSystem).system
        let week = fromWeek
        let keep = keepEdits
        task = Task {
            defer { isWorking = false }
            do {
                for try await update in PlanBrewer(service: service).brew(brief, units: units) {
                    switch update {
                    case .distilling(_, let focus, _): progress = BrewCopy.distillingDay(focus)
                    case .finished(let brewed):
                        try brewed.replaceWeeks(of: plan, from: week, keepEdits: keep, in: context)
                        dismiss()
                    default: break
                    }
                }
            } catch is CancellationError {
            } catch let failure as IntelligenceError {
                error = failure
            } catch {
                self.error = .failed(detail: "\(error)")
            }
        }
    }
}
