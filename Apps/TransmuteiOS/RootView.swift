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

    var body: some View {
        if let profile = profiles.first {
            TabView {
                Tab {
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
                Tab {
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
                Tab {
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
