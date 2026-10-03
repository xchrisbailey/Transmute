import OSLog
import RelevanceKit
import SwiftData
import SwiftUI
import TransmuteCore
import WidgetKit

/// Today at a glance: the mark as a circular complication, the day's name in a corner, the
/// next lift inline, and both in the rectangular one the Smart Stack shows.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayGlance.watchWidgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(glance: entry.glance)
        }
        .configurationDisplayName(Text(WatchWidgetCopy.today))
        .description(Text(WatchWidgetCopy.description))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let glance: TodayGlance

    /// The Smart Stack ranks a running workout first, then a session still to do.
    var relevance: TimelineEntryRelevance? {
        if glance.isRunning { return TimelineEntryRelevance(score: 100) }
        return TimelineEntryRelevance(score: glance.sessionName != nil && !glance.isDone ? 50 : 0)
    }
}

struct TodayProvider: TimelineProvider {
    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "watch-widget")

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, glance: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodayEntry) -> Void) {
        completion(context.isPreview ? TodayEntry(date: .now, glance: .sample) : Self.entry(at: .now))
    }

    /// Now, then tomorrow's day from midnight, when the timeline is read again.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let midnight =
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [Self.entry(at: now), Self.entry(at: midnight)], policy: .after(midnight)))
    }

    /// A workout in progress brings the widget up in the Smart Stack.
    func relevance() async -> WidgetRelevance<Void> {
        WidgetRelevance([WidgetRelevanceAttribute(context: .fitness(.workoutActive))])
    }

    /// Reads the shared store without syncing. A build with no App Group, or a store that
    /// won't open, gives an empty glance, which draws as the mark and the app's name.
    static func entry(at date: Date) -> TodayEntry {
        do {
            let context = ModelContext(try TransmuteStore.makeContainer(.local))
            return TodayEntry(date: date, glance: try TodayGlance.load(from: context, on: date))
        } catch {
            logger.error("Couldn't read the store: \(error)")
            return TodayEntry(date: date, glance: TodayGlance())
        }
    }
}

extension TodayGlance {
    /// For the widget gallery, placeholders and previews.
    static let sample = TodayGlance(
        day: .session("Lower A"),
        nextLift: NextLift(
            name: "Bench press", sets: 5, amount: "5", load: "80 kg", spokenAmount: "5", spokenLoad: "80 kilograms"))
}
