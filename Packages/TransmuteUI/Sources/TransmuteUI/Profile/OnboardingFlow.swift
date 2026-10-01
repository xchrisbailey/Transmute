#if !os(watchOS)
    import SwiftData
    import SwiftUI
    import TransmuteCore

    /// First launch: collects what a plan needs in a few short steps, then saves the profile
    /// and hands off to brewing (#6). Only the body step blocks; the rest can be skipped.
    ///
    /// `notice` sits on the welcome step, for anything the person should know first, such as
    /// Apple Intelligence being off.
    public struct OnboardingFlow<Notice: View>: View {
        let notice: Notice
        let onFinish: (_ profile: Profile, _ brewNow: Bool) -> Void

        @Environment(\.modelContext) private var context
        @Environment(\.health) var health
        @State var draft = ProfileDraft()
        @State var step = Step.welcome
        @State var healthResult: LocalizedStringResource?
        @AccessibilityFocusState private var titleFocused: Bool

        public init(
            @ViewBuilder notice: () -> Notice = { EmptyView() },
            onFinish: @escaping (_ profile: Profile, _ brewNow: Bool) -> Void
        ) {
            self.notice = notice()
            self.onFinish = onFinish
        }

        enum Step: Int, CaseIterable {
            case welcome, body, experience, goals, sport, schedule, equipment, limitations, ready

            var title: LocalizedStringResource? {
                switch self {
                case .welcome, .ready: nil
                case .body: ProfileCopy.bodyTitle
                case .experience: ProfileCopy.experienceTitle
                case .goals: ProfileCopy.goalsTitle
                case .sport: ProfileCopy.sportTitle
                case .schedule: ProfileCopy.scheduleTitle
                case .equipment: ProfileCopy.equipmentTitle
                case .limitations: ProfileCopy.limitationsTitle
                }
            }

            /// Steps that can be skipped, keeping their defaults.
            var isSkippable: Bool {
                ![.welcome, .body, .ready].contains(self)
            }
        }

        /// The steps this person sees: sport only when it's relevant.
        var steps: [Step] {
            Step.allCases.filter { $0 != .sport || draft.suggestsSport }
        }

        public var body: some View {
            VStack(spacing: 0) {
                if step != .welcome, step != .ready {
                    header
                }
                content
                    .frame(maxWidth: 640, maxHeight: .infinity)
                if step != .welcome, step != .ready {
                    footer
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.brand(\.base))
            .animation(.default, value: step)
            .transaction { if accessibilityReduceMotion { $0.animation = nil } }
        }

        @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(position), total: Double(steps.count - 2))
                    .tint(Color.brand(\.magic))
                    .accessibilityHidden(true)
                if let title = step.title {
                    Text(title)
                        .brandFont(.largeTitle)
                        .foregroundStyle(Color.brand(\.ink))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityValue(Text(ProfileCopy.step(position, steps.count - 2)))
                        .accessibilityFocused($titleFocused)
                }
            }
            .padding()
            .frame(maxWidth: 640, alignment: .leading)
        }

        private var position: Int {
            (steps.firstIndex(of: step) ?? 0)
        }

        @ViewBuilder private var content: some View {
            switch step {
            case .welcome: welcome
            case .ready: ready
            case .body: Form { BodySection(draft: $draft) }.scrollContentBackground(.hidden)
            case .experience: Form { ExperienceSection(draft: $draft) }.scrollContentBackground(.hidden)
            case .goals: Form { GoalSection(draft: $draft) }.scrollContentBackground(.hidden)
            case .sport: Form { SportSection(draft: $draft) }.scrollContentBackground(.hidden)
            case .schedule: Form { ScheduleSection(draft: $draft) }.scrollContentBackground(.hidden)
            case .equipment: Form { EquipmentSection(draft: $draft) }.scrollContentBackground(.hidden)
            case .limitations: Form { LimitationsSection(draft: $draft) }.scrollContentBackground(.hidden)
            }
        }

        private var footer: some View {
            HStack {
                Button {
                    go(to: previous)
                } label: {
                    Text(ProfileCopy.back)
                        .frame(minHeight: 44)
                }
                Spacer()
                if step.isSkippable {
                    Button {
                        skip()
                    } label: {
                        Text(ProfileCopy.skip)
                            .frame(minHeight: 44)
                    }
                }
                Button {
                    go(to: next)
                } label: {
                    Text(ProfileCopy.continueButton)
                        .frame(minWidth: 88, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brand(\.magic))
                .disabled(!canContinue)
            }
            .padding()
            .frame(maxWidth: 640)
        }

        var canContinue: Bool {
            switch step {
            case .body: draft.bodyIssues.isEmpty
            case .schedule: draft.scheduleIssues.isEmpty
            default: true
            }
        }

        private var next: Step {
            let index = steps.firstIndex(of: step) ?? 0
            return steps[min(index + 1, steps.count - 1)]
        }

        var previous: Step {
            let index = steps.firstIndex(of: step) ?? 0
            return steps[max(index - 1, 0)]
        }

        /// Puts the step's defaults back and moves on.
        private func skip() {
            let defaults = ProfileDraft()
            switch step {
            case .experience:
                draft.experience = defaults.experience
                draft.knownLifts = []
            case .goals:
                break
            case .sport:
                draft.sport = ""
            case .schedule:
                draft.schedule = defaults.schedule
            case .equipment:
                draft.equipment = defaults.equipment
            case .limitations:
                break
            case .welcome, .body, .ready:
                break
            }
            go(to: next)
        }

        func go(to step: Step) {
            self.step = step
            titleFocused = true
        }

        func prefillFromHealth() async {
            try? await health.requestAccess(.profile)
            let metrics = await health.bodyMetrics()
            draft.prefill(from: metrics)
            healthResult = metrics.isEmpty ? ProfileCopy.healthEmpty : ProfileCopy.healthFilled
        }

        func finish(brewNow: Bool) {
            let profile = Profile()
            context.insert(profile)
            draft.apply(to: profile)
            try? context.save()
            onFinish(profile, brewNow)
        }
    }

    extension OnboardingFlow {
        var welcome: some View {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .accessibilityHidden(true)
                    Text(verbatim: "Transmute")
                        .brandFont(.largeTitle)
                        .foregroundStyle(Color.brand(\.ink))
                        .accessibilityAddTraits(.isHeader)
                    Text(ProfileCopy.welcome)
                        .brandFont(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.brandText(\.subtext))
                    notice
                    if health.isAvailable {
                        VStack(spacing: 12) {
                            Text(ProfileCopy.healthPrefill)
                                .brandFont(.body)
                                .foregroundStyle(Color.brand(\.ink))
                                .multilineTextAlignment(.center)
                            Button {
                                Task { await prefillFromHealth() }
                            } label: {
                                Label {
                                    Text(ProfileCopy.useHealth)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                }
                            }
                            .buttonStyle(.bordered)
                            if let healthResult {
                                Text(healthResult)
                                    .brandFont(.label)
                                    .foregroundStyle(Color.brandText(\.subtext))
                            }
                        }
                        .padding()
                        .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
                    }
                    Button {
                        go(to: .body)
                    } label: {
                        Text(ProfileCopy.getStarted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand(\.magic))
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }

        var ready: some View {
            ScrollView {
                VStack(spacing: 20) {
                    Image("Mark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    Text(ProfileCopy.readyTitle)
                        .brandFont(.largeTitle)
                        .foregroundStyle(Color.brand(\.ink))
                        .accessibilityAddTraits(.isHeader)
                    Text(ProfileCopy.readyBody)
                        .brandFont(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.brandText(\.subtext))
                    Button {
                        finish(brewNow: true)
                    } label: {
                        Text(Copy.brewPlan)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brand(\.magic))
                    Button {
                        finish(brewNow: false)
                    } label: {
                        Text(ProfileCopy.later)
                    }
                    Button {
                        go(to: previous)
                    } label: {
                        Text(ProfileCopy.back)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
    }

    #Preview {
        OnboardingFlow { _, _ in }
            .modelContainer(try! TransmuteStore.makeContainer(.inMemory))  // swiftlint:disable:this force_try
    }
#endif
