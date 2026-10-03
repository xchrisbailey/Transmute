import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// One weekday of one week: a session card, or an empty slot a day can be dropped on.
struct PlanGridCell: View {
    let plan: Plan
    let week: Int
    let weekday: Weekday
    let day: PlanDay?
    let units: Units
    let rework: (PlanDay) -> Void

    @State private var isTargeted = false

    var body: some View {
        Group {
            if let day {
                PlanGridDayCard(day: day, plan: plan, units: units) {
                    rework(day)
                }
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.brand(\.magic), lineWidth: 3)
            }
        }
        .dropDestination(for: PlanGridItem.self) { items, _ in
            items.first?.drop(in: plan, week: week, weekday: weekday) ?? false
        } isTargeted: {
            isTargeted = $0
        }
    }

    private var empty: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.brand(\.surface1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(minHeight: 56)
            .contentShape(.rect)
            .accessibilityElement()
            .accessibilityLabel(
                Text(verbatim: "\(PlanGridCopy.weekdayName(weekday)), \(String(localized: PlanGridCopy.noSession))"))
    }
}

/// A session in the grid: focus, length, markers and its exercises. The heading drags the
/// whole day; the menu does the same moves without dragging.
struct PlanGridDayCard: View {
    let day: PlanDay
    let plan: Plan
    let units: Units
    let rework: () -> Void

    private var isLogged: Bool {
        (day.workouts ?? []).contains { $0.endedAt != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                heading
                Menu {
                    actions
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel(Text(PlanGridCopy.dayOptions))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            ForEach(day.orderedExercises) { planned in
                PlanGridExerciseRow(planned: planned, day: day, plan: plan, units: units)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.brand(\.mantle), in: .rect(cornerRadius: 12))
        .contextMenu { actions }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: day.focus)
                .font(.brand(.body))
                .bold()
                .foregroundStyle(Color.brand(\.ink))
            HStack(spacing: 6) {
                Text(BrewCopy.minutes(day.estimatedMinutes))
                    .brandFont(.label)
                if day.isEdited {
                    Image(systemName: "pencil")
                }
                if isLogged {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandText(\.done))
                }
            }
            .foregroundStyle(Color.brandText(\.subtext))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .draggable(PlanGridItem(day: day, in: plan)) {
            Text(verbatim: day.focus)
                .brandFont(.label)
                .padding(8)
                .background(Color.brand(\.mantle), in: .rect(cornerRadius: 8))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spokenLabel))
        .accessibilityAddTraits(.isHeader)
        .accessibilityActions { actions }
    }

    /// "Monday, Lower and power, About 55 min, Edited, Logged".
    private var spokenLabel: String {
        var parts = [
            PlanGridCopy.weekdayName(day.weekday), day.focus, String(localized: BrewCopy.minutes(day.estimatedMinutes)),
        ]
        if day.isEdited { parts.append(String(localized: PlanCopy.edited)) }
        if isLogged { parts.append(String(localized: PlanCopy.logged)) }
        return parts.joined(separator: ", ")
    }

    /// Rework, then a move to each other weekday. A weekday that has a session swaps with it.
    @ViewBuilder private var actions: some View {
        Button {
            rework()
        } label: {
            Label {
                Text(Copy.reworkDay)
            } icon: {
                Image(systemName: "sparkles")
            }
        }
        Divider()
        ForEach(1...7, id: \.self) { weekday in
            if weekday != day.weekday {
                Button {
                    PlanEditor.move(day, to: weekday)
                } label: {
                    Text(PlanGridCopy.moveDayTo(PlanGridCopy.weekdayName(weekday)))
                }
            }
        }
    }
}
