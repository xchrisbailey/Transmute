import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// Brew a plan (#9): the profile goes in, a plan distils onto the screen day by day, and the
/// person keeps it or brews again. Nothing is saved until they keep it.
public struct BrewPlanView: View {
    let profile: Profile
    let device: String
    let onKept: (Plan) -> Void

    @State private var session: BrewSession
    @State private var status: IntelligenceStatus
    @State private var saveFailed = false
    @Environment(\.modelContext) private var context
    @Environment(\.health) private var health
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Plan> { $0.isActive }) private var activePlans: [Plan]

    public init(
        profile: Profile, service: any IntelligenceService, device: String, onKept: @escaping (Plan) -> Void = { _ in }
    ) {
        self.profile = profile
        self.device = device
        self.onKept = onKept
        _session = State(initialValue: BrewSession(brewer: PlanBrewer(service: service)))
        _status = State(initialValue: IntelligenceStatus(service: service))
    }

    private var units: Units {
        Units(system: profile.unitSystem)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch session.state {
                case .idle, .failed:
                    start
                case .brewing:
                    progress
                case .preview(let plan):
                    PlanPreview(plan: plan, units: units)
                    previewActions
                }
            }
            .padding()
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.brand(\.base))
        .navigationTitle(Text(Copy.brewPlan))
        .task { await status.watch() }
        .alert(Text(Copy.savePlanError), isPresented: $saveFailed) {}
        .sensoryFeedback(.success, trigger: session.state.isPreview)
    }

    // MARK: Start

    private var start: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(BrewCopy.intro)
                .brandFont(.body)
                .foregroundStyle(Color.brand(\.ink))
            profileSummary
            IntelligenceNotice(availability: status.availability)
            if case .failed(let error) = session.state {
                Label {
                    Text(error.message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .brandFont(.body)
                .foregroundStyle(Color.brandText(\.alert))
            }
            Button {
                Task { await brew() }
            } label: {
                Text(Copy.brewPlan)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand(\.magic))
            .disabled(!status.availability.canGenerate)
            if !activePlans.isEmpty {
                Text(BrewCopy.replacesActive)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            Text(BrewCopy.disclaimer)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
        }
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !profile.goalText.isEmpty {
                Text(verbatim: profile.goalText)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(Color.brand(\.ink))
            }
            Text(
                BrewCopy.profileSummary(
                    profile.schedule.daysPerWeek, profile.schedule.sessionMinutes, profile.schedule.weeks)
            )
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
            NavigationLink {
                ProfileView(profile: profile)
            } label: {
                Text(BrewCopy.editProfile)
                    .brandFont(.label)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
    }

    private func brew() async {
        var outside: String?
        if health.isAvailable {
            try? await health.requestAccess(.trainingLoad)
            let week = DateInterval(start: Date.now.addingTimeInterval(-7 * 86_400), end: .now)
            outside = OutsideLoad(await health.otherWorkouts(in: week)).promptDescription
        }
        session.start(TrainingBrief(profile, outsideLoad: outside), units: units.system)
    }

    // MARK: Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let name = session.planName {
                Text(verbatim: name)
                    .brandFont(.largeTitle)
                    .foregroundStyle(Color.brand(\.ink))
                    .accessibilityAddTraits(.isHeader)
            }
            if let rationale = session.rationale {
                Text(Copy.whyThisPlan(rationale))
                    .brandFont(.body)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if !session.phases.isEmpty {
                PhaseBar(phases: session.phases, weekCount: profile.schedule.weeks)
            }
            ForEach(session.distilled) { day in
                DistilledDayRow(phase: day.phase, focus: day.focus, exercises: day.exercises, isDone: true)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
            }
            HStack(spacing: 12) {
                ProgressView()
                if let status = session.status {
                    Text(status)
                        .brandFont(.body)
                        .foregroundStyle(Color.brandText(\.magic))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
            if !session.current.isEmpty {
                DistilledDayRow(phase: nil, focus: nil, exercises: session.current, isDone: false)
            }
            Button(role: .cancel) {
                session.cancel()
            } label: {
                Text(ProfileCopy.cancel)
            }
        }
        .animation(reduceMotion ? nil : .default, value: session.distilled)
    }

    private var previewActions: some View {
        VStack(spacing: 12) {
            Button {
                do {
                    if let plan = try session.keep(in: context, device: device) { onKept(plan) }
                } catch {
                    saveFailed = true
                }
            } label: {
                Text(BrewCopy.keep)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand(\.magic))
            Button {
                Task { await brew() }
            } label: {
                Text(BrewCopy.brewAgain)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            Text(Copy.brewedOn(device: device))
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
        }
    }
}

extension BrewSession.State {
    var isPreview: Bool {
        if case .preview = self { return true }
        return false
    }
}

/// One distilled day while brewing: its focus and the exercises picked so far.
struct DistilledDayRow: View {
    let phase: String?
    let focus: String?
    let exercises: [String]
    let isDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let focus {
                HStack {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle.dotted")
                        .foregroundStyle(isDone ? Color.brandText(\.done) : Color.brandText(\.magic))
                        .accessibilityHidden(true)
                    Text(verbatim: [phase, focus].compactMap { $0 }.joined(separator: " · "))
                        .brandFont(.exerciseTitle)
                        .foregroundStyle(Color.brand(\.ink))
                }
            }
            Text(verbatim: exercises.joined(separator: ", "))
                .brandFont(.body)
                .foregroundStyle(Color.brandText(\.subtext))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = try! TransmuteStore.makeContainer(.inMemory)  // swiftlint:disable:this force_try
    let profile = SampleData.profile()
    container.mainContext.insert(profile)
    return NavigationStack {
        BrewPlanView(profile: profile, service: PreviewIntelligenceService(), device: "iPhone")
    }
    .modelContainer(container)
}
