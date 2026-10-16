import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteSettingsUI
import TransmuteUI

struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()
    let device = "iPhone"
    @AppStorage("rootTab") private var tab = "today"
    @State private var beginRequest: WorkoutBeginRequest?
    @State private var openRequest: WorkoutOpenRequest?

    var body: some View {
        if let profile = profiles.first {
            TabView(selection: $tab) {
                Tab(value: "today") {
                    NavigationStack {
                        TodayView(plan: plans.first, profile: profile, consumingBeginRequest: $beginRequest)
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
                        HistoryView(profile: profile, plan: plans.first, consumingOpenRequest: $openRequest)
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
            .followsDeepLinks { follow($0) }
            .trainingReminders(plan: plans.first) { tab = "today" }
        } else {
            OnboardingFlow {
                // After delete-all, this is where the person lands.
                ErasureNotice()
                LiveIntelligenceNotice(service: service)
            } onFinish: { _, _ in
                ErasureNotice.clear()
            }
        }
    }

    private func follow(_ link: DeepLink) {
        switch link {
        case .today, .beginToday:
            tab = "today"
            beginRequest = link == .beginToday ? WorkoutBeginRequest() : nil
        case .log:
            tab = "log"
        case .workout(let id):
            tab = "log"
            openRequest = WorkoutOpenRequest(workoutID: id)
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
