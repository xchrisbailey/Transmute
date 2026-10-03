import Foundation
import TransmuteCore

/// Strings for the plan's week grid (#17). All plain: they name moves and targets.
enum PlanGridCopy {
    static let moveUp = LocalizedStringResource(
        "plain.planGrid.moveUp", defaultValue: "Move up", bundle: .main,
        comment: "plain. Move an exercise one place earlier in its day.")

    static let moveDown = LocalizedStringResource(
        "plain.planGrid.moveDown", defaultValue: "Move down", bundle: .main,
        comment: "plain. Move an exercise one place later in its day.")

    static let moveToDay = LocalizedStringResource(
        "plain.planGrid.moveToDay", defaultValue: "Move to another day", bundle: .main,
        comment: "plain. Menu listing the days an exercise can move to.")

    static func moveDayTo(_ weekday: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.planGrid.moveDayTo", defaultValue: "Move to \(weekday)", bundle: .main,
            comment: "plain. Move a session to another weekday; the argument is the weekday, e.g. Tuesday.")
    }

    static let editTargets = LocalizedStringResource(
        "plain.planGrid.editTargets", defaultValue: "Edit targets", bundle: .main,
        comment: "plain. Opens an exercise's sets, reps, weight and rest.")

    static let sets = LocalizedStringResource(
        "plain.planGrid.sets", defaultValue: "Sets", bundle: .main,
        comment: "plain. Target field: how many sets.")

    static let noSession = LocalizedStringResource(
        "plain.planGrid.noSession", defaultValue: "No session", bundle: .main,
        comment: "plain. A weekday with nothing planned.")

    static let dayOptions = LocalizedStringResource(
        "plain.planGrid.dayOptions", defaultValue: "Day options", bundle: .main,
        comment: "plain. Menu on a day: rework it or move it.")

    /// A weekday's name in the person's language. Plan weekdays count from Monday as 1.
    static func weekdayName(_ weekday: Weekday, calendar: Calendar = .current) -> String {
        calendar.standaloneWeekdaySymbols[weekday % 7]
    }
}
