import Foundation
import TransmuteCore

/// The words every widget puts around a `TodayGlance`, on the watch, the iPhone and the Mac.
/// Plain, as everything outside the app is.
enum GlanceCopy {
    static let today = LocalizedStringResource(
        "plain.today.title", defaultValue: "Today", bundle: .main, comment: "plain. Tab and title of the Today screen.")

    static let todayDescription = LocalizedStringResource(
        "plain.widget.today.description", defaultValue: "Today's session, your streak and this week's sessions.",
        bundle: .main, comment: "plain. Describes the Today widget in the iPhone and Mac widget gallery.")

    static let watchTodayDescription = LocalizedStringResource(
        "plain.watch.widget.description", defaultValue: "Today's session and your next lift.", bundle: .main,
        comment: "plain. Describes the watch widget in the widget gallery.")

    static let weekDescription = LocalizedStringResource(
        "plain.widget.week.description", defaultValue: "Your streak and this week's sessions.", bundle: .main,
        comment: "plain. Describes the watch's This week widget in the widget gallery.")

    static let restDay = LocalizedStringResource(
        "plain.today.restDay", defaultValue: "Rest day", bundle: .main, comment: "plain. Today has no session.")

    static let done = LocalizedStringResource(
        "plain.done", defaultValue: "Done", bundle: .main, comment: "plain. Button.")

    static let inProgress = LocalizedStringResource(
        "plain.widget.inProgress", defaultValue: "In progress", bundle: .main,
        comment: "plain. Widget, a workout is going right now.")

    static let nextUp = LocalizedStringResource(
        "plain.widget.nextUp", defaultValue: "Next up", bundle: .main,
        comment: "plain. Widget, above the first exercise of the next session.")

    static let noPlan = LocalizedStringResource(
        "plain.widget.noPlan", defaultValue: "Open Transmute to make a plan.", bundle: .main,
        comment: "plain. Widget, there's no plan to show.")

    static let resume = LocalizedStringResource(
        "plain.today.resume", defaultValue: "Resume workout", bundle: .main,
        comment: "plain. Go back to a workout in progress.")

    static let thisWeek = LocalizedStringResource(
        "plain.widget.thisWeek", defaultValue: "This week", bundle: .main,
        comment: "plain. Widget, title of this week's sessions; also the name of the watch's week widget.")

    static let thisWeekSuffix = LocalizedStringResource(
        "plain.widget.thisWeekSuffix", defaultValue: "this week", bundle: .main,
        comment: "plain. Widget, after the sessions figure, e.g. 2/3 this week.")

    static let nothingThisWeek = LocalizedStringResource(
        "plain.widget.nothingThisWeek", defaultValue: "No sessions planned", bundle: .main,
        comment: "plain. Widget, the plan has no sessions this week, or there's no plan.")

    static func sessions(_ done: Int, of planned: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.widget.sessions", defaultValue: "Sessions this week: \(done) of \(planned)", bundle: .main,
            comment: "plain. VoiceOver, sessions done out of planned, e.g. Sessions this week: 2 of 3.")
    }

    static func streak(weeks: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.widget.streak", defaultValue: "\(weeks) weeks in a row", bundle: .main,
            comment: "plain. Widget, weeks in a row with every planned session done, e.g. 3 weeks in a row.")
    }

    static func streakShort(weeks: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.widget.streakShort", defaultValue: "\(weeks) wk", bundle: .main,
            comment: "plain. Widget, the streak in weeks where there's little room, e.g. 3 wk.")
    }

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

    /// The sessions figure as it's drawn: "2/3".
    static func figure(_ week: TodayGlance.Week) -> String {
        "\(week.done)/\(week.planned)"
    }

    /// What VoiceOver says of the day, e.g. "Lower A. Next: Bench press, 5 sets of 5 at 80
    /// kilograms".
    static func spoken(_ glance: TodayGlance) -> String {
        var parts = [title(glance)]
        if glance.isDone { parts.append(String(localized: done)) }
        if glance.isRunning { parts.append(String(localized: inProgress)) }
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

    /// What VoiceOver says of the week, e.g. "Sessions this week: 2 of 3. 3 weeks in a row".
    /// `nil` with no sessions this week and no streak.
    static func spokenWeek(_ glance: TodayGlance) -> String? {
        var parts: [String] = []
        if glance.week.planned > 0 {
            parts.append(String(localized: sessions(glance.week.done, of: glance.week.planned)))
        }
        if glance.streakWeeks > 0 { parts.append(String(localized: streak(weeks: glance.streakWeeks))) }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// The day, then the week; with no plan, the day and where to make one.
    static func spokenInFull(_ glance: TodayGlance) -> String {
        [spoken(glance), spokenWeek(glance), glance.isEmpty ? String(localized: noPlan) : nil]
            .compactMap(\.self).joined(separator: ". ")
    }
}
