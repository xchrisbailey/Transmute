import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// Every plan (#10): the active one, and earlier ones kept with their history. Any can be made
/// active again, or a new one brewed.
struct PlanHistoryView: View {
    let profile: Profile
    let service: any IntelligenceService
    let device: String

    @Environment(\.modelContext) private var context
    @Query(sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]

    var body: some View {
        List {
            Section {
                NavigationLink {
                    BrewPlanView(profile: profile, service: service, device: device)
                } label: {
                    Label {
                        Text(PlanCopy.newPlan)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            Section {
                ForEach(plans) { plan in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: plan.name)
                                .brandFont(.exerciseTitle)
                            Text(plan.createdAt, format: .dateTime.day().month().year())
                                .brandFont(.label)
                                .foregroundStyle(Color.brandText(\.subtext))
                        }
                        Spacer()
                        if plan.isActive {
                            Badge(text: PlanCopy.active, tint: Color.brand(\.magic))
                        } else {
                            Button {
                                try? PlanEditor.activate(plan, in: context)
                            } label: {
                                Text(PlanCopy.makeActive)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(PlanCopy.earlierPlans)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(PlanCopy.plans))
    }
}
