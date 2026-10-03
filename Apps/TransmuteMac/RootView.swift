import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteUI

/// Onboarding until there's a profile, then the window: a sidebar and its four panes.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()

    var body: some View {
        if let profile = profiles.first {
            MacShell(profile: profile, plan: plans.first, service: service, streakWeeks: nil)
                .tint(Color.brand(\.magic))
        } else {
            OnboardingFlow {
                LiveIntelligenceNotice(service: service)
            } onFinish: { _, _ in
            }
        }
    }
}

/// The Mac window (#17): Today, Plan, Log and Progress in a sidebar, with the streak and the
/// profile underneath. The menu bar drives it through `WindowActions`.
struct MacShell: View {
    let profile: Profile
    let plan: Plan?
    let service: any IntelligenceService
    /// Weeks in the current streak, shown in the sidebar. `nil` hides the line.
    let streakWeeks: Int?
    let device = "Mac"

    @SceneStorage("sidebar.section") private var section = SidebarSection.today
    @State private var beginsWorkout = false
    @State private var showsRebrew = false
    @State private var showsProfile = false
    @FocusState private var searchIsFocused: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(section: $section, profile: profile, streakWeeks: streakWeeks) {
                showsProfile = true
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            NavigationStack {
                pane
            }
            // Each section starts from its own root.
            .id(section)
        }
        .focusedSceneValue(\.windowActions, actions)
        .sheet(isPresented: $showsProfile) {
            NavigationStack {
                ProfileView(profile: profile)
                    .formStyle(.grouped)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showsProfile = false
                            } label: {
                                Text(MacCopy.done)
                            }
                        }
                    }
            }
            .frame(minWidth: 560, minHeight: 640)
        }
        .sheet(isPresented: $showsRebrew) {
            if let plan {
                RebrewSheet(plan: plan, profile: profile, service: service, currentWeek: PlanEditor.week(of: plan))
            }
        }
    }

    @ViewBuilder private var pane: some View {
        switch section {
        case .today:
            TodayView(plan: plan, profile: profile, beginsWorkout: $beginsWorkout)
        case .plan:
            if let plan {
                PlanView(plan: plan, profile: profile, service: service, device: device)
            } else {
                BrewPlanView(profile: profile, service: service, device: device)
            }
        case .log:
            LogTableView(profile: profile, plan: plan, searchFocus: $searchIsFocused)
        case .progress:
            ProgressPane()
        }
    }

    private var actions: WindowActions {
        WindowActions(
            section: section,
            show: { section = $0 },
            newWorkout: {
                section = .today
                beginsWorkout = true
            },
            brewPlan: {
                section = .plan
                showsRebrew = plan != nil
            },
            findInLog: { searchIsFocused = true })
    }
}
