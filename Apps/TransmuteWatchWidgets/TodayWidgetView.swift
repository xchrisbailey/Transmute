import SwiftUI
import TransmuteCore
import TransmuteUI
import WidgetKit

/// One glance drawn for whichever complication slot it's in. Words are the system font and
/// numbers Geist Mono; mauve marks the day and becomes the face's tint on tinted faces.
struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let glance: TodayGlance

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.watchScreen }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: GlanceCopy.spoken(glance)))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            WidgetMark()
                .widgetLabel { Text(GlanceCopy.title(glance)) }
        case .accessoryCorner:
            WidgetMark()
                .widgetLabel { Text(GlanceCopy.title(glance)) }
        case .accessoryInline:
            InlineGlance(glance: glance)
        default:
            RectangularGlance(glance: glance)
        }
    }
}

/// One line: the next lift while there's a session to do, otherwise the day.
struct InlineGlance: View {
    let glance: TodayGlance

    var body: some View {
        if let lift = glance.nextLift, glance.isRunning || (glance.sessionName != nil && !glance.isDone) {
            Text(verbatim: lift.text)
        } else if glance.isDone {
            Label(GlanceCopy.title(glance), systemImage: "checkmark")
        } else {
            Text(GlanceCopy.title(glance))
        }
    }
}

/// The day on top, then the next lift: its name, and its numbers in Geist Mono. With no
/// lift to show, the mark beside the day or the app's name.
struct RectangularGlance: View {
    let glance: TodayGlance

    var body: some View {
        if let lift = glance.nextLift {
            VStack(alignment: .leading, spacing: 0) {
                title
                Text(verbatim: lift.name)
                    .font(.body)
                if let detail = lift.detail {
                    Text(verbatim: detail)
                        .font(.brandNumber(size: 15, relativeTo: .body))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) {
                WidgetMark()
                    .frame(maxHeight: 36)
                title
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var title: some View {
        HStack(spacing: 4) {
            Text(GlanceCopy.title(glance))
            if glance.isDone {
                Image(systemName: "checkmark")
                    .imageScale(.small)
            }
        }
        .font(.headline)
        .foregroundStyle(Color.brand(\.magic))
        .widgetAccentable()
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
                nextLift: .init(name: "Plank", sets: 3, amount: "0:45", spokenAmount: "45 seconds"))),
        TodayEntry(
            date: .now,
            glance: TodayGlance(
                day: .rest,
                nextLift: .init(
                    name: "Half-kneeling landmine press", sets: 3, amount: "8", load: "176.5 lb", spokenAmount: "8",
                    spokenLoad: "176.5 pounds"))),
        TodayEntry(
            date: .now,
            glance: TodayGlance(
                day: .session("Lower A"), isDone: true,
                nextLift: .init(name: "Acceleration sprint", sets: 6, amount: "10 m", spokenAmount: "10 metres"))),
        TodayEntry(date: .now, glance: TodayGlance()),
    ]
}

#Preview("Circular", as: .accessoryCircular) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[4]
}

#Preview("Corner", as: .accessoryCorner) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[2]
    TodayEntry.samples[4]
}

#Preview("Inline", as: .accessoryInline) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[1]
    TodayEntry.samples[2]
    TodayEntry.samples[3]
    TodayEntry.samples[4]
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TodayWidget()
} timeline: {
    TodayEntry.samples[0]
    TodayEntry.samples[1]
    TodayEntry.samples[2]
    TodayEntry.samples[3]
    TodayEntry.samples[4]
}
