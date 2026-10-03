import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

/// "This week, distilled": a few sentences about the week, written on-device by the AI from
/// the week's numbers, or from a template when the AI is off. Offers to rework the next
/// session when lifts stalled.
struct WeekSummaryCard: View {
    let digest: ProgressStats.WeekDigest
    let plan: Plan?
    let profile: Profile
    let service: any IntelligenceService
    let units: Units

    @State private var summary: WeekSummary?
    @State private var reworking: PlanDay?

    /// The week's numbers as the writer takes them: formatted here, in the person's units, so
    /// the AI only ever repeats figures it was given.
    private var input: WeekSummaryInput {
        WeekSummaryInput(
            sessionsDone: digest.sessionsDone, sessionsPlanned: digest.sessionsPlanned,
            volume: digest.volumeKg > 0 ? units.formatWeight(kg: digest.volumeKg) : nil,
            volumeChangePercent: digest.volumeChange.map { Int(($0 * 100).rounded()) },
            records: digest.records.map {
                "\($0.name) \(String(localized: RecordFormat.label($0.mark, units: units))), "
                    + RecordFormat.value($0.mark, units: units)
            },
            wentUp: digest.wentUp.map {
                "\($0.name) \(units.formatWeight(kg: $0.fromKg)) → \(units.formatWeight(kg: $0.toKg))"
            },
            stalled: digest.stalled.map(\.name), streakWeeks: digest.streakWeeks, goal: profile.goalText)
    }

    /// The session a rework would change: the next one that isn't logged yet.
    private var nextDay: PlanDay? {
        guard let plan else { return nil }
        let today = TodayPlan(plan: plan)
        return today.isDone ? today.next : today.day ?? today.next
    }

    var body: some View {
        let input = input
        let summary = summary ?? WeekSummaryWriter.template(input)
        ProgressCard(title: Copy.weekDistilled) {
            Text(verbatim: summary.headline)
                .brandFont(.body)
                .bold()
                .foregroundStyle(Color.brand(\.ink))
            ForEach(summary.lines, id: \.self) { line in
                Text(verbatim: line)
                    .brandFont(.body)
                    .foregroundStyle(Color.brand(\.ink))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if summary.isFromAI {
                Text(ProgressCopy.writtenOnDevice)
                    .font(.caption)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if summary.suggestsRework, let nextDay {
                Button {
                    reworking = nextDay
                } label: {
                    Text(ProgressCopy.reworkNextWeek)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Color.brand(\.magic))
            }
        }
        .task(id: input) {
            // The template shows at once; the AI's version replaces it when it's ready.
            self.summary = WeekSummaryWriter.template(input)
            self.summary = await WeekSummaryWriter(service: service).write(input)
        }
        .sheet(item: $reworking) { day in
            if let plan {
                ReworkDaySheet(day: day, plan: plan, profile: profile, service: service)
            }
        }
    }
}
