import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteSettingsUI
import TransmuteUI

/// Onboarding until there's a profile. Then Today, where workouts are run (#11), the log
/// of past workouts (#14), and the plan, which is the brew screen until there is one. Every
/// tab has the profile and Settings (#18) in its toolbar.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()
    let device = "iPhone"
    /// The tab last shown, kept between launches.
    @AppStorage("rootTab") private var tab = "today"
    /// Set by a widget's button (#19): Today begins the session once it's on screen.
    @State private var beginsWorkout = false
    /// Set by Open workout and Spotlight (#19): the log shows this workout once it's on screen.
    @State private var openedWorkout: UUID?
    private let router = DeepLinkRouter.shared

    var body: some View {
        if let profile = profiles.first {
            TabView(selection: $tab) {
                Tab(value: "today") {
                    NavigationStack {
                        TodayView(plan: plans.first, profile: profile, beginsWorkout: $beginsWorkout)
                            .toolbar { profileItems(profile) }
                    }
                } label: {
                    Label {
                        Text(LogCopy.today)
                    } icon: {
                        Image(systemName: "flame")
                    }
                }
                Tab(value: "log") {
                    NavigationStack {
                        HistoryView(profile: profile, plan: plans.first, opening: $openedWorkout)
                            .toolbar { profileItems(profile) }
                    }
                } label: {
                    Label {
                        Text(HistoryCopy.title)
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
                Tab(value: "progress") {
                    NavigationStack {
                        ProgressScreen(plan: plans.first, profile: profile, service: service)
                            .toolbar { profileItems(profile) }
                    }
                } label: {
                    Label {
                        Text(ProgressCopy.title)
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                Tab(value: "plan") {
                    NavigationStack {
                        Group {
                            if let plan = plans.first {
                                PlanView(plan: plan, profile: profile, service: service, device: device)
                            } else {
                                BrewPlanView(profile: profile, service: service, device: device)
                            }
                        }
                        .toolbar { profileItems(profile) }
                    }
                } label: {
                    Label {
                        Text(LogCopy.plan)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .tint(Color.brand(\.magic))
            .workoutPreferences(of: profile)
            .onOpenURL { url in
                if let link = DeepLink(url: url) { follow(link) }
            }
            // An App Intent's link, which may have been waiting since before the window (#19).
            .onChange(of: router.pending, initial: true) {
                if let link = router.take() { follow(link) }
            }
            .trainingReminders(plan: plans.first) { tab = "today" }
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

    /// Goes where a widget, a shortcut or Spotlight pointed.
    private func follow(_ link: DeepLink) {
        switch link {
        case .today, .beginToday:
            tab = "today"
            beginsWorkout = link == .beginToday
        case .log:
            tab = "log"
        case .workout(let id):
            tab = "log"
            openedWorkout = id
        case .plan:
            tab = "plan"
        }
    }

    @ToolbarContentBuilder private func profileItems(_ profile: Profile) -> some ToolbarContent {
        ToolbarItem {
            NavigationLink {
                ProfileView(profile: profile)
            } label: {
                Label {
                    Text(ProfileCopy.profile)
                } icon: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        ToolbarItem {
            NavigationLink {
                SettingsView(profile: profile, service: service)
            } label: {
                Label {
                    Text(SettingsCopy.title)
                } icon: {
                    Image(systemName: "gearshape")
                }
            }
        }
        #if DEBUG
            ToolbarItem {
                NavigationLink {
                    IntelligenceDebugView(service: service)
                } label: {
                    Label {
                        Text(verbatim: "AI debug")
                    } icon: {
                        Image(systemName: "ladybug")
                    }
                }
            }
        #endif
    }
}
