import Foundation
import TransmuteCore

/// What Siri and Shortcuts say for Transmute's App Intents (#19). Plain, short, and written to
/// be heard: weights are said in full, "80 kilograms". A rest day or a quiet week is stated,
/// never judged.
///
/// Intent and parameter titles have to be literals in the intents themselves; everything
/// built at run time is here.
public enum ShortcutCopy {
    // MARK: What's my workout today?

    /// The whole answer, e.g. "Today is Lower A. First up: Bench press, 5 sets of 5 at 80
    /// kilograms. Sessions this week: 1 of 3."
    public static func today(_ glance: TodayGlance) -> String {
        [String(localized: day(glance)), lift(glance), week(glance.week)].compactMap(\.self).joined(separator: " ")
    }

    /// What today is: a session, one in progress, one already done, rest, or nothing planned.
    public static func day(_ glance: TodayGlance) -> LocalizedStringResource {
        switch glance.day {
        case .session(let name) where glance.isRunning:
            LocalizedStringResource(
                "plain.shortcut.today.running", defaultValue: "\(name) is in progress.", bundle: .main,
                comment: "plain. Siri, a workout is going right now, e.g. Lower A is in progress.")
        case .session(let name) where glance.isDone:
            LocalizedStringResource(
                "plain.shortcut.today.done", defaultValue: "\(name) is done for today.", bundle: .main,
                comment: "plain. Siri, today's session is already logged, e.g. Lower A is done for today.")
        case .session(let name):
            LocalizedStringResource(
                "plain.shortcut.today.session", defaultValue: "Today is \(name).", bundle: .main,
                comment: "plain. Siri, today's session by name, e.g. Today is Lower A.")
        case .rest:
            LocalizedStringResource(
                "plain.shortcut.today.rest", defaultValue: "Today is a rest day.", bundle: .main,
                comment: "plain. Siri, the plan has no session today.")
        case .nothingPlanned where glance.isRunning:
            LocalizedStringResource(
                "plain.shortcut.today.runningUnnamed", defaultValue: "A workout is in progress.", bundle: .main,
                comment: "plain. Siri, a workout with no name is going right now.")
        case .nothingPlanned:
            LocalizedStringResource(
                "plain.shortcut.today.nothing",
                defaultValue: "Nothing is planned for today. You can make a plan in Transmute.", bundle: .main,
                comment: "plain. Siri, there's no plan, or the plan has ended.")
        }
    }

    /// The lift that comes next, as a sentence. `nil` once today's session is done, when the
    /// next lift belongs to another day.
    static func lift(_ glance: TodayGlance) -> String? {
        guard let lift = glance.nextLift, !glance.isDone, glance.day != .nothingPlanned || glance.isRunning else {
            return nil
        }
        let words = spoken(lift)
        let sentence =
            if glance.isRunning {
                LocalizedStringResource(
                    "plain.shortcut.today.next", defaultValue: "Next: \(words).", bundle: .main,
                    comment: "plain. Siri, the exercise being done, e.g. Next: Bench press, 5 sets of 5.")
            } else if glance.day == .rest {
                LocalizedStringResource(
                    "plain.shortcut.today.nextSession", defaultValue: "Your next session starts with \(words).",
                    bundle: .main,
                    comment: "plain. Siri, on a rest day, the first exercise of the next session.")
            } else {
                LocalizedStringResource(
                    "plain.shortcut.today.firstUp", defaultValue: "First up: \(words).", bundle: .main,
                    comment: "plain. Siri, the first exercise of today's session, e.g. First up: Bench press.")
            }
        return String(localized: sentence)
    }

    /// A lift as it's said aloud: "Bench press, 5 sets of 5 at 80 kilograms". The same words
    /// the widgets give VoiceOver.
    public static func spoken(_ lift: TodayGlance.NextLift) -> String {
        guard lift.sets > 0, let amount = lift.spokenAmount else { return lift.name }
        let numbers =
            if let load = lift.spokenLoad {
                LocalizedStringResource(
                    "plain.watch.widget.setsAtLoad", defaultValue: "\(lift.sets) sets of \(amount) at \(load)",
                    bundle: .main,
                    comment: "plain. VoiceOver, sets of reps at a load, e.g. 5 sets of 5 at 80 kilograms.")
            } else {
                LocalizedStringResource(
                    "plain.watch.widget.sets", defaultValue: "\(lift.sets) sets of \(amount)", bundle: .main,
                    comment: "plain. VoiceOver, sets of reps, time or distance, e.g. 5 sets of 5, 3 sets of 45 seconds."
                )
            }
        return "\(lift.name), \(String(localized: numbers))"
    }

    /// This week's sessions. With none done yet it says what's planned rather than "0 of 3".
    /// `nil` when the week has no sessions.
    public static func week(_ week: TodayGlance.Week) -> String? {
        guard week.planned > 0 else { return nil }
        if week.done == 0 {
            return String(
                localized: LocalizedStringResource(
                    "plain.shortcut.today.weekPlanned", defaultValue: "\(week.planned) sessions planned this week.",
                    bundle: .main, comment: "plain. Siri, sessions planned this week when none is done yet."))
        }
        return String(
            localized: LocalizedStringResource(
                "plain.shortcut.today.week", defaultValue: "Sessions this week: \(week.done) of \(week.planned).",
                bundle: .main, comment: "plain. Siri, sessions done out of planned, e.g. Sessions this week: 2 of 3."))
    }

    // MARK: The snippet

    /// The snippet's heading: the session's name, "Rest day", or "Nothing planned".
    public static func title(_ glance: TodayGlance) -> String {
        switch glance.day {
        case .session(let name): name
        case .rest:
            String(
                localized: LocalizedStringResource(
                    "plain.today.restDay", defaultValue: "Rest day", bundle: .main,
                    comment: "plain. Today has no session."))
        case .nothingPlanned:
            String(
                localized: LocalizedStringResource(
                    "plain.shortcut.today.nothingTitle", defaultValue: "Nothing planned", bundle: .main,
                    comment: "plain. Siri's snippet, heading when there's no session and no plan."))
        }
    }

    /// "In progress" or "Done" beside the heading. `nil` for a session still to do.
    public static func status(_ glance: TodayGlance) -> LocalizedStringResource? {
        if glance.isRunning {
            LocalizedStringResource(
                "plain.widget.inProgress", defaultValue: "In progress", bundle: .main,
                comment: "plain. Widget, a workout is going right now.")
        } else if glance.isDone {
            LocalizedStringResource("plain.done", defaultValue: "Done", bundle: .main, comment: "plain. Button.")
        } else {
            nil
        }
    }

    /// The week in the snippet: "1 of 3 this week". `nil` when the week has no sessions.
    public static func weekFigure(_ week: TodayGlance.Week) -> String? {
        guard week.planned > 0 else { return nil }
        return String(
            localized: LocalizedStringResource(
                "plain.shortcut.today.weekFigure", defaultValue: "\(week.done) of \(week.planned) this week",
                bundle: .main, comment: "plain. Siri's snippet, sessions done of planned, e.g. 1 of 3 this week."))
    }

    // MARK: Begin today's workout

    /// What Begin today's workout does for a glance.
    public enum Begin: Equatable, Sendable {
        /// Start today's session, or go back into the workout that's running.
        case begin
        /// Nothing to start: show Today.
        case showToday
    }

    public static func begin(_ glance: TodayGlance) -> Begin {
        glance.isRunning || (glance.sessionName != nil && !glance.isDone) ? .begin : .showToday
    }

    /// Said as the app opens, e.g. "Starting Lower A." With nothing to start it says why and
    /// that Today is open.
    public static func beginning(_ glance: TodayGlance) -> LocalizedStringResource {
        switch glance.day {
        case .session(let name) where glance.isRunning:
            LocalizedStringResource(
                "plain.shortcut.begin.resuming", defaultValue: "Back to \(name).", bundle: .main,
                comment: "plain. Siri, going back into a workout that's running, e.g. Back to Lower A.")
        case .nothingPlanned where glance.isRunning:
            LocalizedStringResource(
                "plain.shortcut.begin.resumingUnnamed", defaultValue: "Back to your workout.", bundle: .main,
                comment: "plain. Siri, going back into a running workout with no name.")
        case .session(let name) where glance.isDone:
            LocalizedStringResource(
                "plain.shortcut.begin.done", defaultValue: "\(name) is done for today. Transmute is open on Today.",
                bundle: .main, comment: "plain. Siri, today's session is already logged, so nothing starts.")
        case .session(let name):
            LocalizedStringResource(
                "plain.shortcut.begin.starting", defaultValue: "Starting \(name).", bundle: .main,
                comment: "plain. Siri, today's session begins, e.g. Starting Lower A.")
        case .rest:
            LocalizedStringResource(
                "plain.shortcut.begin.rest", defaultValue: "Today is a rest day. Transmute is open on Today.",
                bundle: .main, comment: "plain. Siri, no session today, so nothing starts.")
        case .nothingPlanned:
            LocalizedStringResource(
                "plain.shortcut.begin.nothing",
                defaultValue: "Nothing is planned for today. Transmute is open on Today.", bundle: .main,
                comment: "plain. Siri, no plan or the plan has ended, so nothing starts.")
        }
    }

    // MARK: Log bodyweight

    /// e.g. "Logged 79.4 kilograms." The weight comes from `BodyweightLog.spoken`.
    public static func logged(_ weight: String, inHealth: Bool) -> LocalizedStringResource {
        if inHealth {
            LocalizedStringResource(
                "plain.shortcut.weight.loggedHealth", defaultValue: "Logged \(weight), and saved it to Health.",
                bundle: .main, comment: "plain. Siri, a bodyweight was stored and written to Health.")
        } else {
            LocalizedStringResource(
                "plain.shortcut.weight.logged", defaultValue: "Logged \(weight).", bundle: .main,
                comment: "plain. Siri, a bodyweight was stored, e.g. Logged 79.4 kilograms.")
        }
    }

    public static let askWeight = LocalizedStringResource(
        "plain.shortcut.weight.ask", defaultValue: "What's your weight?", bundle: .main,
        comment: "plain. Siri asks for the bodyweight to log.")

    public static let askWeightAgain = LocalizedStringResource(
        "plain.shortcut.weight.askAgain", defaultValue: "That doesn't sound like a bodyweight. What's your weight?",
        bundle: .main, comment: "plain. Siri, the weight was far too low or high; asks again.")

    public static let weightNeedsProfile = LocalizedStringResource(
        "plain.shortcut.weight.needsProfile", defaultValue: "Open Transmute and set up your profile first.",
        bundle: .main, comment: "plain. Siri, there's no profile to log a bodyweight on yet.")

    public static let weightFailed = LocalizedStringResource(
        "plain.shortcut.weight.failed", defaultValue: "Couldn't save that. Try again in Transmute.", bundle: .main,
        comment: "plain. Siri, saving a bodyweight failed.")

    // MARK: Workouts and plans in Spotlight

    /// Under a workout in Spotlight and Shortcuts: "6 exercises · 8,420 kg". The volume is left
    /// out when nothing was lifted.
    public static func workoutSummary(_ summary: WorkoutSummary, units: Units) -> String {
        let exercises = String(
            localized: LocalizedStringResource(
                "plain.shortcut.workout.exercises", defaultValue: "\(summary.exercises) exercises", bundle: .main,
                comment: "plain. Spotlight, number of exercises in a logged workout."))
        guard summary.volumeKg > 0 else { return exercises }
        return "\(exercises) · \(units.formatWeight(kg: summary.volumeKg))"
    }

    /// Under a plan in Spotlight and Shortcuts: its goal, or how long it runs when it has none.
    public static func planSummary(goal: String, weeks: Int) -> String {
        guard goal.isEmpty else { return goal }
        return String(
            localized: LocalizedStringResource(
                "plain.shortcut.plan.weeks", defaultValue: "\(weeks) weeks", bundle: .main,
                comment: "plain. Spotlight, how long a plan runs, e.g. 8 weeks."))
    }
}
