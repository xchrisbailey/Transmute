import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

/// Onboarding until there's a profile, then brewing until there's a plan, then the plan.
struct RootView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(filter: #Predicate<Plan> { $0.isActive }, sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    let service = FoundationModelsService()
    let device = "Mac"

    var body: some View {
        if let profile = profiles.first {
            NavigationStack {
                Group {
                    if let plan = plans.first {
                        PlanView(plan: plan, profile: profile, service: service, device: device)
                    } else {
                        BrewPlanView(profile: profile, service: service, device: device)
                    }
                }
                .toolbar {
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
                }
            }
        } else {
            OnboardingFlow {
                LiveIntelligenceNotice(service: service)
            } onFinish: { _, _ in
            }
        }
    }
}
