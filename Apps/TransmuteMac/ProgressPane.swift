import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmuteUI

/// Progress at desk width (#16, #17): the charts across the window with the records list
/// beside them.
struct ProgressPane: View {
    let plan: Plan?
    let profile: Profile
    let service: any IntelligenceService

    var body: some View {
        HSplitView {
            ProgressScreen(plan: plan, profile: profile, service: service)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
            RecordsView(since: plan?.startDate, units: Units(profile))
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 380, maxHeight: .infinity)
        }
        .navigationTitle(Text(MacCopy.progress))
    }
}
