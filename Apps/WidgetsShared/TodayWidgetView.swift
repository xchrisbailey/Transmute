import SwiftUI
import TransmuteCore
import TransmuteUI
import WidgetKit

/// One glance drawn for whichever size it's in. Words are the system font and numbers Geist
/// Mono. A tap opens Today; the medium size also has the button that begins the session.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let glance: TodayGlance

    var body: some View {
        switch family {
        #if os(iOS)
            case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                AccessoryToday(glance: glance)
        #endif
        case .systemMedium:
            MediumToday(glance: glance)
                .containerBackground(for: .widget) { Color.brand(\.base) }
                .widgetURL(DeepLink.today.url)
        default:
            SmallToday(glance: glance)
                .containerBackground(for: .widget) { Color.brand(\.base) }
                .widgetURL(DeepLink.today.url)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: GlanceCopy.spokenInFull(glance)))
        }
    }
}

/// The day, the next lift, then the week along the bottom.
struct SmallToday: View {
    let glance: TodayGlance

    var body: some View {
        if glance.isEmpty {
            EmptyToday()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                DayBlock(glance: glance)
                Spacer(minLength: 0)
                if glance.week.planned > 0 {
                    WeekFooter(glance: glance)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// The day and the next lift on the left; the week, the streak and the button on the right.
struct MediumToday: View {
    let glance: TodayGlance

    var body: some View {
        if glance.isEmpty {
            EmptyToday()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: GlanceCopy.spokenInFull(glance)))
        } else {
            HStack(alignment: .top, spacing: 16) {
                DayBlock(glance: glance)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: GlanceCopy.spoken(glance)))
                VStack(alignment: .leading, spacing: 6) {
                    WeekBlock(glance: glance)
                    Spacer(minLength: 0)
                    if glance.isToDo || glance.isRunning {
                        BeginButton(isRunning: glance.isRunning)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

/// What state the day is in, its name, and the next lift with its numbers.
struct DayBlock: View {
    let glance: TodayGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            status
                .font(.caption.weight(.semibold))
            Text(verbatim: GlanceCopy.title(glance))
                .font(.headline)
                .foregroundStyle(Color.brand(\.ink))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            if let lift = glance.nextLift {
                VStack(alignment: .leading, spacing: 0) {
                    if !glance.isToDo && !glance.isRunning {
                        Text(GlanceCopy.nextUp)
                            .font(.caption2)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    Text(verbatim: lift.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.brand(\.ink))
                    if let detail = lift.detail {
                        Text(verbatim: detail)
                            .font(.brandNumber(size: 15, relativeTo: .subheadline))
                            .monospacedDigit()
                            .foregroundStyle(Color.brand(\.ink))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 2)
            }
        }
    }

    /// Each state has its own words and symbol, so it reads without the colour.
    @ViewBuilder private var status: some View {
        if glance.isRunning {
            Label {
                Text(GlanceCopy.inProgress)
            } icon: {
                Image(systemName: "record.circle")
            }
            .labelStyle(StatusLabelStyle())
            .foregroundStyle(Color.brandText(\.now))
        } else if glance.isDone {
            Label {
                Text(GlanceCopy.done)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .labelStyle(StatusLabelStyle())
            .foregroundStyle(Color.brandText(\.done))
        } else {
            Text(GlanceCopy.today)
                .foregroundStyle(Color.brandText(\.subtext))
        }
    }
}

/// A symbol tight against its word, where the system's label would space them for a list.
private struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
        .lineLimit(1)
    }
}

/// The small size's bottom edge: the pills, then "2/3 this week" and the streak.
struct WeekFooter: View {
    let glance: TodayGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WeekPills(week: glance.week)
            HStack(spacing: 4) {
                Text(verbatim: GlanceCopy.figure(glance.week))
                    .font(.brandNumber(size: 13, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand(\.ink))
                if glance.streakWeeks > 0 {
                    Spacer(minLength: 0)
                    StreakLabel(weeks: glance.streakWeeks, isShort: true)
                        .foregroundStyle(Color.brand(\.ink))
                } else {
                    Text(GlanceCopy.thisWeekSuffix)
                        .font(.caption)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

/// The medium size's right half: "This week", the figure and its pills, then the streak.
struct WeekBlock: View {
    let glance: TodayGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GlanceCopy.thisWeek)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandText(\.subtext))
            if glance.week.planned > 0 {
                HStack(spacing: 8) {
                    Text(verbatim: GlanceCopy.figure(glance.week))
                        .font(.brandNumber(size: 20, relativeTo: .title3))
                        .monospacedDigit()
                        .foregroundStyle(Color.brand(\.ink))
                    WeekPills(week: glance.week, height: 6)
                }
            } else {
                Text(GlanceCopy.nothingThisWeek)
                    .font(.subheadline)
                    .foregroundStyle(Color.brand(\.ink))
            }
            if glance.streakWeeks > 0 {
                StreakLabel(weeks: glance.streakWeeks)
                    .foregroundStyle(Color.brand(\.ink))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: GlanceCopy.spokenWeek(glance) ?? String(localized: GlanceCopy.nothingThisWeek)))
    }
}

/// The one mauve action: opens the app and begins today's session, or goes back into the
/// one that's running. Where the Home Screen is tinted it's an outline, so the words stay
/// readable.
struct BeginButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let isRunning: Bool

    var body: some View {
        Link(destination: DeepLink.beginToday.url) {
            label
        }
    }

    var label: some View {
        Text(isRunning ? GlanceCopy.resume : Copy.beginWork)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 32)
            .foregroundStyle(renderingMode == .fullColor ? Color.brand(\.base) : Color.primary)
            .background {
                if renderingMode == .fullColor {
                    Capsule().fill(Color.brand(\.magic))
                } else {
                    Capsule().strokeBorder(Color.primary, lineWidth: 1.5)
                        .widgetAccentable()
                }
            }
    }
}

/// No plan to show: the mark, the app's name and where to go.
struct EmptyToday: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetMark()
                .frame(width: 36, height: 36)
            Spacer(minLength: 0)
            Text(verbatim: "Transmute")
                .font(.headline)
                .foregroundStyle(Color.brand(\.ink))
                .widgetAccentable()
            Text(GlanceCopy.noPlan)
                .font(.caption)
                .foregroundStyle(Color.brandText(\.subtext))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Previews

extension TodayEntry {
    fileprivate static let samples: [TodayEntry] = [
        TodayEntry(date: .now, glance: .sample),
        TodayEntry(
            date: .now,
            glance: TodayGlance(
                day: .session("Speed, agility and conditioning"), isRunning: true,
                nextLift: .init(name: "Plank", sets: 3, amount: "0:45", spokenAmount: "45 seconds"),
                streakWeeks: 12, week: .init(done: 2, planned: 3))),
        TodayEntry(
            date: .now,
            glance: TodayGlance(
                day: .rest,
                nextLift: .init(
                    name: "Half-kneeling landmine press", sets: 3, amount: "8", load: "176.5 lb", spokenAmount: "8",
                    spokenLoad: "176.5 pounds"), week: .init(done: 1, planned: 4))),
        TodayEntry(
            date: .now,
            glance: TodayGlance(
                day: .session("Lower A"), isDone: true,
                nextLift: .init(name: "Acceleration sprint", sets: 6, amount: "10 m", spokenAmount: "10 metres"),
                streakWeeks: 4, week: .init(done: 3, planned: 3))),
        TodayEntry(date: .now, glance: TodayGlance()),
    ]
}

#Preview("Small", as: .systemSmall) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[1]
    TodayEntry.samples[2]
    TodayEntry.samples[3]
    TodayEntry.samples[4]
}

#Preview("Medium", as: .systemMedium) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[1]
    TodayEntry.samples[2]
    TodayEntry.samples[3]
    TodayEntry.samples[4]
}

#if os(iOS)
    #Preview("Lock Screen, rectangular", as: .accessoryRectangular) {
        TodayWidget()
    } timeline: {
        TodayEntry.samples[0]
        TodayEntry.samples[1]
        TodayEntry.samples[3]
        TodayEntry.samples[4]
    }

    #Preview("Lock Screen, circular", as: .accessoryCircular) {
        TodayWidget()
    } timeline: {
        TodayEntry.samples[0]
        TodayEntry.samples[4]
    }

    #Preview("Lock Screen, inline", as: .accessoryInline) {
        TodayWidget()
    } timeline: {
        TodayEntry.samples[0]
        TodayEntry.samples[3]
    }
#endif
