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
            .accessibilityLabel(Text(verbatim: WatchWidgetCopy.spoken(glance)))
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryCircular:
            WidgetMark()
                .widgetLabel { Text(WatchWidgetCopy.title(glance)) }
        case .accessoryCorner:
            WidgetMark()
                .widgetLabel { Text(WatchWidgetCopy.title(glance)) }
        case .accessoryInline:
            InlineGlance(glance: glance)
        default:
            RectangularGlance(glance: glance)
        }
    }
}

/// The mark. On tinted faces it's desaturated and takes the tint, so it needs no template copy.
struct WidgetMark: View {
    var body: some View {
        Image("Mark")
            .resizable()
            .widgetAccentedRenderingMode(.accentedDesaturated)
            .scaledToFit()
    }
}

/// One line: the next lift while there's a session to do, otherwise the day.
struct InlineGlance: View {
    let glance: TodayGlance

    var body: some View {
        if let lift = glance.nextLift, glance.isRunning || (glance.sessionName != nil && !glance.isDone) {
            Text(verbatim: lift.text)
        } else if glance.isDone {
            Label(WatchWidgetCopy.title(glance), systemImage: "checkmark")
        } else {
            Text(WatchWidgetCopy.title(glance))
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
            Text(WatchWidgetCopy.title(glance))
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

/// The widget's words. Plain, as everything on the watch is.
enum WatchWidgetCopy {
    static let today = LocalizedStringResource(
        "plain.today.title", defaultValue: "Today", bundle: .main, comment: "plain. Tab and title of the Today screen.")

    static let description = LocalizedStringResource(
        "plain.watch.widget.description", defaultValue: "Today's session and your next lift.", bundle: .main,
        comment: "plain. Describes the watch widget in the widget gallery.")

    static let restDay = LocalizedStringResource(
        "plain.today.restDay", defaultValue: "Rest day", bundle: .main, comment: "plain. Today has no session.")

    static let done = LocalizedStringResource(
        "plain.done", defaultValue: "Done", bundle: .main, comment: "plain. Button.")

    static func next(_ lift: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.widget.next", defaultValue: "Next: \(lift)", bundle: .main,
            comment: "plain. VoiceOver, the next exercise, e.g. Next: Bench press, 5 sets of 5 at 80 kilograms.")
    }

    static func sets(_ count: Int, of amount: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.widget.sets", defaultValue: "\(count) sets of \(amount)", bundle: .main,
            comment: "plain. VoiceOver, sets of reps, time or distance, e.g. 5 sets of 5, 3 sets of 45 seconds.")
    }

    static func sets(_ count: Int, of amount: String, at load: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.widget.setsAtLoad", defaultValue: "\(count) sets of \(amount) at \(load)", bundle: .main,
            comment: "plain. VoiceOver, sets of reps at a load, e.g. 5 sets of 5 at 80 kilograms.")
    }

    /// The session's name, "Rest day", or the app's name when nothing is planned.
    static func title(_ glance: TodayGlance) -> String {
        switch glance.day {
        case .session(let name): name
        case .rest: String(localized: restDay)
        case .nothingPlanned: "Transmute"
        }
    }

    /// What VoiceOver says, e.g. "Lower A. Next: Bench press, 5 sets of 5 at 80 kilograms".
    static func spoken(_ glance: TodayGlance) -> String {
        var parts = [title(glance)]
        if glance.isDone { parts.append(String(localized: done)) }
        if let lift = glance.nextLift {
            var words = [lift.name]
            if lift.sets > 0, let amount = lift.spokenAmount {
                let phrase = lift.spokenLoad.map { sets(lift.sets, of: amount, at: $0) } ?? sets(lift.sets, of: amount)
                words.append(String(localized: phrase))
            }
            parts.append(String(localized: next(words.joined(separator: ", "))))
        }
        return parts.joined(separator: ". ")
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
