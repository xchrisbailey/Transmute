import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// The active plan (#10): name, why, phases, then every week with its days. The current week
/// starts open. Edits happen on each day; rebrew and earlier plans are in the toolbar.
public struct PlanView: View {
    @Bindable var plan: Plan
    let profile: Profile
    let service: any IntelligenceService
    let device: String

    @Environment(\.modelContext) private var context
    @State private var openWeeks: Set<Int> = []
    @State private var showsRebrew = false

    public init(plan: Plan, profile: Profile, service: any IntelligenceService, device: String) {
        self.plan = plan
        self.profile = profile
        self.service = service
        self.device = device
    }

    private var currentWeek: Int {
        PlanEditor.week(of: plan)
    }

    private var units: Units {
        Units(profile)
    }

    public var body: some View {
        List {
            Section {
                header
            }
            ForEach(1...max(1, plan.weekCount), id: \.self) { week in
                Section {
                    DisclosureGroup(isExpanded: binding(for: week)) {
                        ForEach(plan.orderedDays.filter { $0.week == week }) { day in
                            NavigationLink {
                                PlanDayView(day: day, plan: plan, profile: profile, service: service)
                            } label: {
                                PlanDayRow(day: day, date: PlanEditor.date(of: day, in: plan))
                            }
                        }
                    } label: {
                        weekLabel(week)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.brand(\.base))
        .navigationTitle(Text(BrewCopy.activePlan))
        .toolbar {
            UndoButtons()
            ToolbarItem {
                Menu {
                    Button {
                        showsRebrew = true
                    } label: {
                        Label {
                            Text(Copy.rebrew)
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                    }
                    NavigationLink {
                        PlanHistoryView(profile: profile, service: service, device: device)
                    } label: {
                        Label {
                            Text(PlanCopy.plans)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                } label: {
                    Label {
                        Text(PlanCopy.plans)
                    } icon: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showsRebrew) {
            RebrewSheet(plan: plan, profile: profile, service: service, currentWeek: currentWeek)
        }
        .onAppear {
            if openWeeks.isEmpty { openWeeks = [currentWeek] }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: plan.name)
                .brandFont(.largeTitle)
                .foregroundStyle(Color.brand(\.ink))
                .accessibilityAddTraits(.isHeader)
            if !plan.goalSummary.isEmpty {
                Text(verbatim: plan.goalSummary)
                    .brandFont(.exerciseTitle)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if !plan.rationale.isEmpty {
                Text(Copy.whyThisPlan(plan.rationale))
                    .brandFont(.body)
                    .foregroundStyle(Color.brand(\.ink))
            }
            if !plan.phases.isEmpty {
                PhaseBar(phases: plan.phases, weekCount: plan.weekCount, currentWeek: currentWeek)
            }
            if let brewedBy = plan.brewedBy {
                Text(verbatim: brewedBy)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
        .padding(.vertical, 4)
    }

    private func weekLabel(_ week: Int) -> some View {
        HStack {
            Text(BrewCopy.week(week))
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
            if week == currentWeek {
                Badge(text: PlanCopy.thisWeek, tint: Color.brand(\.now))
            }
            if plan.phase(forWeek: week)?.isDeload == true {
                Badge(text: BrewCopy.deload, tint: Color.brand(\.surface1))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func binding(for week: Int) -> Binding<Bool> {
        Binding {
            openWeeks.contains(week)
        } set: { isOpen in
            if isOpen { openWeeks.insert(week) } else { openWeeks.remove(week) }
        }
    }
}

/// A small label in a capsule. Always text, so its meaning doesn't rest on colour (#22).
struct Badge: View {
    let text: LocalizedStringResource
    let tint: Color

    var body: some View {
        Text(text)
            .brandFont(.label)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(Color.brand(\.base))
            .background(tint, in: .capsule)
    }
}

/// One day in the week list.
struct PlanDayRow: View {
    let day: PlanDay
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date, format: .dateTime.weekday(.wide))
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                if day.isEdited {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.brandText(\.subtext))
                        .accessibilityLabel(Text(PlanCopy.edited))
                }
                if !(day.workouts ?? []).isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandText(\.done))
                        .accessibilityLabel(Text(PlanCopy.logged))
                }
            }
            Text(verbatim: day.focus)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
            Text(
                verbatim: [
                    String(localized: BrewCopy.exercisesCount(day.orderedExercises.count)),
                    String(localized: BrewCopy.minutes(day.estimatedMinutes)),
                ].joined(separator: " · ")
            )
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Undo and redo for plan edits, backed by the model context's undo manager.
struct UndoButtons: ToolbarContent {
    @Environment(\.modelContext) private var context

    var body: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                context.undoManager?.undo()
            } label: {
                Label {
                    Text(PlanCopy.undo)
                } icon: {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            Button {
                context.undoManager?.redo()
            } label: {
                Label {
                    Text(PlanCopy.redo)
                } icon: {
                    Image(systemName: "arrow.uturn.forward")
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
    }
}
