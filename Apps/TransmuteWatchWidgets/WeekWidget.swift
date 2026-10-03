import SwiftUI
import TransmuteCore
import TransmuteUI
import WidgetKit

/// This week in the Smart Stack (#19): sessions done of sessions planned, and the streak.
/// Its own widget, because the Today one already fills its three lines.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayGlance.watchWeekWidgetKind, provider: TodayProvider()) { entry in
            WeekWidgetView(glance: entry.glance)
        }
        .configurationDisplayName(Text(GlanceCopy.thisWeek))
        .description(Text(GlanceCopy.weekDescription))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let glance: TodayGlance

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.watchScreen }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: spoken))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular: CircularWeek(glance: glance)
        default: RectangularWeek(glance: glance)
        }
    }

    /// e.g. "This week. Sessions this week: 2 of 3. 3 weeks in a row".
    private var spoken: String {
        [
            String(localized: GlanceCopy.thisWeek),
            GlanceCopy.spokenWeek(glance) ?? String(localized: GlanceCopy.nothingThisWeek),
        ]
        .joined(separator: ". ")
    }
}

/// The week's sessions as a ring around the figure. With nothing planned, the mark.
struct CircularWeek: View {
    let glance: TodayGlance

    var body: some View {
        if glance.week.planned > 0 {
            Gauge(value: Double(min(glance.week.done, glance.week.planned)), in: 0...Double(glance.week.planned)) {
                EmptyView()
            } currentValueLabel: {
                Text(verbatim: GlanceCopy.figure(glance.week))
                    .font(.brandNumber(size: 14, relativeTo: .caption))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(Color.brand(\.done))
            .widgetAccentable()
        } else {
            WidgetMark()
        }
    }
}

/// "This week" in mauve, as Today's title is, then the figure beside its pills and the streak.
struct RectangularWeek: View {
    let glance: TodayGlance

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(GlanceCopy.thisWeek)
                .font(.headline)
                .foregroundStyle(Color.brand(\.magic))
                .widgetAccentable()
            if glance.week.planned > 0 {
                HStack(spacing: 6) {
                    Text(verbatim: GlanceCopy.figure(glance.week))
                        .font(.brandNumber(size: 17, relativeTo: .body))
                    WeekPills(week: glance.week, height: 6)
                }
            } else {
                Text(GlanceCopy.nothingThisWeek)
                    .font(.body)
            }
            if glance.streakWeeks > 0 {
                StreakLabel(weeks: glance.streakWeeks, size: 15)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Week, rectangular", as: .accessoryRectangular) {
    WeekWidget()
} timeline: {
    TodayEntry(date: .now, glance: .sample)
    TodayEntry(date: .now, glance: TodayGlance(day: .rest, streakWeeks: 12, week: .init(done: 4, planned: 4)))
    TodayEntry(date: .now, glance: TodayGlance(day: .session("Lower A"), week: .init(done: 0, planned: 3)))
    TodayEntry(date: .now, glance: TodayGlance())
}

#Preview("Week, circular", as: .accessoryCircular) {
    WeekWidget()
} timeline: {
    TodayEntry(date: .now, glance: .sample)
    TodayEntry(date: .now, glance: TodayGlance())
}
