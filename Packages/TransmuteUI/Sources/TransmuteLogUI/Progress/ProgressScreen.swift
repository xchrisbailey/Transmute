import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// Progress (#16): this week's figures, the weekly summary, and charts of estimated 1RM,
/// volume, bodyweight, conditioning and plan adherence. Cards flow into as many columns as
/// fit, so the iPhone gets one and the Mac gets the roomy version.
public struct ProgressScreen: View {
    let plan: Plan?
    let profile: Profile
    let service: any IntelligenceService

    @Query(filter: #Predicate<Workout> { $0.endedAt != nil }, sort: \Workout.startedAt)
    private var workouts: [Workout]
    @Query private var records: [PersonalRecord]
    let library = ExerciseLibrary.bundled

    public init(plan: Plan?, profile: Profile, service: any IntelligenceService) {
        self.plan = plan
        self.profile = profile
        self.service = service
    }

    private var units: Units {
        Units(profile)
    }

    public var body: some View {
        ScrollView {
            if workouts.isEmpty && (profile.bodyweights ?? []).isEmpty {
                Text(ProgressCopy.empty)
                    .brandFont(.body)
                    .foregroundStyle(Color.brandText(\.subtext))
                    .multilineTextAlignment(.center)
                    .padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)], spacing: 16) {
                    cards
                }
                .padding()
            }
        }
        .background(Color.brand(\.base))
        .navigationTitle(Text(ProgressCopy.title))
    }

    @ViewBuilder private var cards: some View {
        let weeks = plan.map { ProgressStats.adherence(of: $0) } ?? []
        let digest = ProgressStats.digest(plan: plan, workouts: workouts, records: records)
        FiguresCard(
            sessions: plan.map { ProgressStats.sessionsKPI(of: $0) },
            volume: ProgressStats.volumeKPI(workouts),
            bodyweight: ProgressStats.bodyweightKPI(profile.bodyweights ?? [], since: plan?.startDate),
            lifts: ProgressStats.liftKPIs(plan: plan, workouts: workouts, records: records, since: plan?.startDate),
            streak: ProgressStats.streak(weeks), units: units)
        WeekSummaryCard(digest: digest, plan: plan, profile: profile, service: service, units: units)
        MaxChartCard(
            lifts: ProgressStats.keyLifts(of: plan, workouts: workouts), workouts: workouts, records: records,
            units: units)
        VolumeChartCard(workouts: workouts, units: units)
        BodyweightChartCard(points: ProgressStats.bodyweightTrend(profile.bodyweights ?? []), units: units)
        ForEach(ProgressStats.conditioning(workouts)) { series in
            ConditioningChartCard(series: series)
        }
        if !weeks.isEmpty {
            AdherenceChartCard(weeks: weeks)
        }
    }
}

/// A titled platter every Progress card sits on.
struct ProgressCard<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .brandFont(.exerciseTitle)
                .foregroundStyle(Color.brand(\.ink))
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.brand(\.mantle), in: .rect(cornerRadius: 16))
    }
}

/// This week at a glance: the streak, sessions, volume, bodyweight and the key lifts.
struct FiguresCard: View {
    let sessions: ProgressStats.SessionsKPI?
    let volume: ProgressStats.VolumeKPI
    let bodyweight: ProgressStats.BodyweightKPI?
    let lifts: [ProgressStats.LiftKPI]
    let streak: Int
    let units: Units

    var body: some View {
        ProgressCard(title: ProgressCopy.thisWeek) {
            if streak > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Label {
                        Text(Copy.streak(weeks: streak))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.now))
                    Text(ProgressCopy.streakHelp)
                        .font(.caption)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .topLeading)], spacing: 12) {
                if let sessions {
                    figure(
                        ProgressCopy.sessions,
                        String(localized: ProgressCopy.sessionsValue(sessions.done, of: sessions.planned)))
                }
                figure(
                    ProgressCopy.volume, units.formatWeight(kg: volume.thisWeekKg),
                    // A week that's barely begun would only read as a drop.
                    note: volume.thisWeekKg > 0
                        ? volume.change.map { ProgressCopy.versusLastWeek(Self.percent($0)) } : nil)
                if let bodyweight {
                    figure(
                        ProgressCopy.bodyweight, units.formatWeight(kg: bodyweight.currentKg),
                        note: bodyweight.changeKg.map { ProgressCopy.sincePlanStart(signed($0)) })
                }
                ForEach(lifts) { lift in
                    figure(
                        LocalizedStringResource(stringLiteral: lift.name), units.formatWeight(kg: lift.currentKg),
                        note: lift.changeKg.map { ProgressCopy.sincePlanStart(signed($0)) })
                }
            }
        }
    }

    private func figure(_ label: LocalizedStringResource, _ value: String, note: LocalizedStringResource? = nil)
        -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
                .lineLimit(2)
            Text(verbatim: value)
                .brandNumberFont(size: 22, relativeTo: .title2)
                .foregroundStyle(Color.brand(\.ink))
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// e.g. "+2.5 kg" or "−1 kg".
    private func signed(_ kg: Double) -> String {
        "\(kg < 0 ? "−" : "+")\(units.formatWeight(kg: abs(kg)))"
    }

    /// e.g. "+6%" or "−12%".
    static func percent(_ fraction: Double) -> String {
        let percent = Int((fraction * 100).rounded())
        return "\(percent < 0 ? "−" : "+")\(abs(percent))%"
    }
}
