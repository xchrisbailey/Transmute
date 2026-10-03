import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmutePlanUI
import TransmuteUI

/// Onboarding until there's a profile. Then Today, where workouts are run (#11), the log
/// of past workouts (#14), and the plan, which is the brew screen until there is one.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()
    let device = "iPhone"
    /// The tab last shown, kept between launches.
    @AppStorage("rootTab") private var tab = "today"

    var body: some View {
        if let profile = profiles.first {
            TabView(selection: $tab) {
                Tab(value: "today") {
                    NavigationStack {
                        TodayView(plan: plans.first, profile: profile)
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
                        HistoryView(profile: profile, plan: plans.first)
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
        } else {
            OnboardingFlow {
                LiveIntelligenceNotice(service: service)
            } onFinish: { _, _ in
            }
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
