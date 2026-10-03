import OSLog
import SwiftData
import SwiftUI
import TransmuteCore
import WidgetKit

/// Today on the Home Screen, the Lock Screen and the Mac desktop (#19): the session, the
/// next lift, the streak and this week's sessions, with a button to begin where a widget
/// can have one.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TodayGlance.widgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(glance: entry.glance)
        }
        .configurationDisplayName(Text(GlanceCopy.today))
        .description(Text(GlanceCopy.todayDescription))
        .supportedFamilies(Self.families)
    }

    /// The Lock Screen's families are the iPhone's alone.
    static var families: [WidgetFamily] {
        #if os(iOS)
            [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
            [.systemSmall, .systemMedium]
        #endif
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let glance: TodayGlance

    /// A Smart Stack ranks a running workout first, then a session still to do.
    var relevance: TimelineEntryRelevance? {
        if glance.isRunning { return TimelineEntryRelevance(score: 100) }
        return TimelineEntryRelevance(score: glance.sessionName != nil && !glance.isDone ? 50 : 0)
    }
}

struct TodayProvider: TimelineProvider {
    private static let logger = Logger(subsystem: Transmute.bundlePrefix, category: "widget")

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, glance: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodayEntry) -> Void) {
        completion(context.isPreview ? TodayEntry(date: .now, glance: .sample) : Self.entry(at: .now))
    }

    /// Now, then tomorrow's day from midnight, when the timeline is read again. In between,
    /// the app reloads it whenever the store is saved.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodayEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let midnight =
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(86_400)
        completion(Timeline(entries: [Self.entry(at: now), Self.entry(at: midnight)], policy: .after(midnight)))
    }

    /// Reads the shared store without syncing. A build with no App Group, as the Mac's is
    /// without a signing team, or a store that won't open, gives an empty glance, which draws
    /// as the mark and a line pointing at the app.
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
