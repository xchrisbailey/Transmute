import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The kept plan at a glance, until the full plan view (#10).
public struct ActivePlanSummary: View {
    let plan: Plan

    public init(plan: Plan) {
        self.plan = plan
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: plan.name)
                    .brandFont(.largeTitle)
                    .foregroundStyle(Color.brand(\.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(Copy.whyThisPlan(plan.rationale))
                    .brandFont(.body)
                    .foregroundStyle(Color.brandText(\.subtext))
                PhaseBar(phases: plan.phases, weekCount: plan.weekCount)
            }
            .padding()
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.brand(\.base))
        .navigationTitle(Text(BrewCopy.activePlan))
    }
}
