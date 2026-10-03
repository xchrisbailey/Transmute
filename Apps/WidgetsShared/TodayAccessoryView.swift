#if os(iOS)
    import SwiftUI
    import TransmuteCore
    import TransmuteUI
    import WidgetKit

    /// Today on the Lock Screen. There it's drawn in one vibrant tone, so every state has
    /// its own symbol or words and nothing leans on colour.
    struct AccessoryToday: View {
        @Environment(\.widgetFamily) private var family
        let glance: TodayGlance

        var body: some View {
            content
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(DeepLink.today.url)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: GlanceCopy.spokenInFull(glance)))
        }

        @ViewBuilder private var content: some View {
            switch family {
            case .accessoryCircular: CircularToday(glance: glance)
            case .accessoryInline: InlineToday(glance: glance)
            default: RectangularToday(glance: glance)
            }
        }
    }

    /// This week's sessions as a ring around the figure. Without a week to show, the mark.
    struct CircularToday: View {
        let glance: TodayGlance

        var body: some View {
            if glance.week.planned > 0 {
                Gauge(value: Double(min(glance.week.done, glance.week.planned)), in: 0...Double(glance.week.planned)) {
                    EmptyView()
                } currentValueLabel: {
                    Text(verbatim: GlanceCopy.figure(glance.week))
                        .font(.brandNumber(size: 14, relativeTo: .caption))
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    WidgetMark()
                        .padding(10)
                }
            }
        }
    }

    /// One line: the next lift while there's a session to do, otherwise the day.
    struct InlineToday: View {
        let glance: TodayGlance

        var body: some View {
            if let lift = glance.nextLift, glance.isRunning || glance.isToDo {
                Text(verbatim: lift.text)
            } else if glance.isDone {
                Label(GlanceCopy.title(glance), systemImage: "checkmark")
            } else {
                Text(verbatim: GlanceCopy.title(glance))
            }
        }
    }

    /// The day, the next lift on one line, then the week's figure and the streak.
    struct RectangularToday: View {
        let glance: TodayGlance

        var body: some View {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(verbatim: GlanceCopy.title(glance))
                    if glance.isDone {
                        Image(systemName: "checkmark")
                            .imageScale(.small)
                    } else if glance.isRunning {
                        Image(systemName: "record.circle")
                            .imageScale(.small)
                    }
                }
                .font(.headline)
                .widgetAccentable()
                if let lift = glance.nextLift {
                    HStack(spacing: 4) {
                        Text(verbatim: lift.name)
                        if let detail = lift.detail {
                            Text(verbatim: detail)
                                .font(.brandNumber(size: 13, relativeTo: .caption))
                                .monospacedDigit()
                                .layoutPriority(1)
                        }
                    }
                    .font(.subheadline)
                } else if glance.isEmpty {
                    Text(GlanceCopy.noPlan)
                        .font(.caption)
                }
                HStack(spacing: 8) {
                    if glance.week.planned > 0 {
                        HStack(spacing: 4) {
                            Text(verbatim: GlanceCopy.figure(glance.week))
                                .font(.brandNumber(size: 13, relativeTo: .caption))
                                .monospacedDigit()
                            Text(GlanceCopy.thisWeekSuffix)
                                .font(.caption)
                        }
                    }
                    if glance.streakWeeks > 0 {
                        StreakLabel(weeks: glance.streakWeeks, isShort: true)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
#endif
