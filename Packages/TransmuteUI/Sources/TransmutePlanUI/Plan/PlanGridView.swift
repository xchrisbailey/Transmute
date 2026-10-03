import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// The whole plan as a week grid (#17): a row for each week, a column for each weekday.
/// Exercises drag within a day or onto another, days drag to another weekday, and every move
/// is also in a menu and an accessibility action (#22). Rebrew is in the toolbar.
public struct PlanGridView: View {
    let plan: Plan
    let profile: Profile
    let service: any IntelligenceService
    let device: String

    @State private var showsRebrew = false
    @State private var reworking: PlanDay?
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var gutterWidth: CGFloat = 96

    static let spacing: CGFloat = 8
    static let padding: CGFloat = 12

    public init(plan: Plan, profile: Profile, service: any IntelligenceService, device: String) {
        self.plan = plan
        self.profile = profile
        self.service = service
        self.device = device
    }

    private var currentWeek: Int {
        PlanEditor.week(of: plan)
    }

    public var body: some View {
        GeometryReader { proxy in
            // Columns share the window when it's wide and keep a readable width when it isn't.
            let fixed = gutterWidth + Self.spacing * 9 + Self.padding * 2
            let column = max(columnWidth, ((proxy.size.width - fixed) / 7).rounded(.down))
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 0) {
                    weekdayHeader(column: column)
                    weeks(column: column)
                }
                .frame(height: proxy.size.height, alignment: .top)
            }
        }
        .background(Color.brand(\.base))
        .navigationTitle(Text(BrewCopy.activePlan))
        #if os(macOS)
            .navigationSubtitle(Text(verbatim: plan.name))
        #endif
        .toolbar {
            UndoButtons()
            ToolbarItem {
                Button {
                    showsRebrew = true
                } label: {
                    Label {
                        Text(Copy.rebrew)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            }
        }
        .sheet(isPresented: $showsRebrew) {
            RebrewSheet(plan: plan, profile: profile, service: service, currentWeek: currentWeek)
                .planGridSheetSize()
        }
        .sheet(item: $reworking) { day in
            ReworkDaySheet(day: day, plan: plan, profile: profile, service: service)
                .planGridSheetSize()
        }
    }

    private func weekdayHeader(column: CGFloat) -> some View {
        HStack(spacing: Self.spacing) {
            Color.clear.frame(width: gutterWidth, height: 1)
            ForEach(1...7, id: \.self) { weekday in
                Text(verbatim: PlanGridCopy.weekdayName(weekday))
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                    .frame(width: column, alignment: .leading)
            }
        }
        .padding(.horizontal, Self.padding + Self.spacing)
        .padding(.vertical, 8)
        // The cells say their own weekday, so VoiceOver skips the column headings.
        .accessibilityHidden(true)
    }

    private func weeks(column: CGFloat) -> some View {
        ScrollViewReader { reader in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Self.spacing) {
                    ForEach(1...max(1, plan.weekCount), id: \.self) { week in
                        PlanGridWeekRow(
                            plan: plan, week: week, isCurrent: week == currentWeek,
                            units: Units(profile), columnWidth: column, gutterWidth: gutterWidth
                        ) { day in
                            reworking = day
                        }
                        .id(week)
                    }
                }
                .padding([.horizontal, .bottom], Self.padding)
            }
            .onAppear {
                reader.scrollTo(currentWeek, anchor: .top)
            }
        }
    }
}

extension View {
    /// Sheets size to their content on the Mac, and a form on its own has none.
    fileprivate func planGridSheetSize() -> some View {
        #if os(macOS)
            frame(minWidth: 460, minHeight: 380)
        #else
            self
        #endif
    }
}

/// One week: its number, phase and markers, then a cell for each weekday.
struct PlanGridWeekRow: View {
    let plan: Plan
    let week: Int
    let isCurrent: Bool
    let units: Units
    let columnWidth: CGFloat
    let gutterWidth: CGFloat
    let rework: (PlanDay) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: PlanGridView.spacing) {
            label
                .frame(width: gutterWidth, alignment: .leading)
            ForEach(1...7, id: \.self) { weekday in
                PlanGridCell(
                    plan: plan, week: week, weekday: weekday,
                    day: PlanEditor.day(of: plan, week: week, weekday: weekday), units: units, rework: rework
                )
                .frame(width: columnWidth)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(PlanGridView.spacing)
        // The current week has an outline as well as its "This week" badge (#22).
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.brand(\.now), lineWidth: 2)
            }
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(BrewCopy.week(week))
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
            if let phase = plan.phase(forWeek: week) {
                Text(verbatim: phase.name)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                if phase.isDeload {
                    Badge(text: BrewCopy.deload, tint: Color.brand(\.surface1))
                }
            }
            if isCurrent {
                Badge(text: PlanCopy.thisWeek, tint: Color.brand(\.now))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    let plan = try? container.mainContext.fetch(FetchDescriptor<Plan>()).first
    let profile = try? container.mainContext.fetch(FetchDescriptor<Profile>()).first
    return NavigationStack {
        if let plan, let profile {
            PlanGridView(plan: plan, profile: profile, service: PreviewIntelligenceService(), device: "Mac")
        }
    }
    .modelContainer(container)
    .frame(minWidth: 900, minHeight: 600)
}
