import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteSettingsUI
import TransmuteUI

/// Onboarding until there's a profile, then the window: a sidebar and its four panes.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()

    /// Weeks in a row with every planned session done, for the sidebar. Hidden at zero.
    private var streak: Int? {
        let weeks = plans.first.map { ProgressStats.streak(ProgressStats.adherence(of: $0)) } ?? 0
        return weeks > 0 ? weeks : nil
    }

    var body: some View {
        if let profile = profiles.first {
            MacShell(profile: profile, plan: plans.first, service: service, streakWeeks: streak)
                .tint(Color.brand(\.magic))
                .workoutPreferences(of: profile)
        } else {
            OnboardingFlow {
                // After delete-all (#18), this is where the person lands.
                ErasureNotice()
                LiveIntelligenceNotice(service: service)
            } onFinish: { _, _ in
                ErasureNotice.clear()
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
        // A widget's tap, or its button (#19).
        .onOpenURL { url in
            guard let link = DeepLink(url: url) else { return }
            section = .today
            beginsWorkout = link == .beginToday
        }
        .trainingReminders(plan: plan) { section = .today }
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

    /// The plan as the week grid, or as the same list the iPhone shows.
    @AppStorage("planGrid") private var showsPlanGrid = true

    @ViewBuilder private var pane: some View {
        switch section {
        case .today:
            TodayView(plan: plan, profile: profile, beginsWorkout: $beginsWorkout)
        case .plan:
            if let plan {
                Group {
                    if showsPlanGrid {
                        PlanGridView(plan: plan, profile: profile, service: service, device: device)
                    } else {
                        PlanView(plan: plan, profile: profile, service: service, device: device)
                    }
                }
                .toolbar {
                    ToolbarItem {
                        Picker(selection: $showsPlanGrid) {
                            Label {
                                Text(MacCopy.planGrid)
                            } icon: {
                                Image(systemName: "square.grid.3x3")
                            }
                            .tag(true)
                            Label {
                                Text(MacCopy.planList)
                            } icon: {
                                Image(systemName: "list.bullet")
                            }
                            .tag(false)
                        } label: {
                            Text(MacCopy.planLayout)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            } else {
                BrewPlanView(profile: profile, service: service, device: device)
            }
        case .log:
            LogTableView(profile: profile, plan: plan, searchFocus: $searchIsFocused)
        case .progress:
            ProgressPane(plan: plan, profile: profile, service: service)
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

/// The Settings window (#18), opened with ⌘, from the app menu. It has its own query, since
/// it can be open before there's a profile and after one is deleted.
struct SettingsRoot: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    let service = FoundationModelsService()

    var body: some View {
        SettingsView(profile: profiles.first, service: service)
            .tint(Color.brand(\.magic))
    }
}
