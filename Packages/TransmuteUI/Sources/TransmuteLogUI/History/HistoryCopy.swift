import Foundation

/// Strings for the workout log (#14). Plain throughout; the empty log and deletes use the
/// wording from the brand book (#3).
public enum HistoryCopy {
    public static let title = LocalizedStringResource(
        "plain.history.title", defaultValue: "Log", bundle: .main,
        comment: "plain. Tab and title of the workout history.")

    static func weekOf(_ date: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.history.weekOf", defaultValue: "Week of \(date)", bundle: .main,
            comment: "plain. Section heading in the log, e.g. Week of Sep 21.")
    }

    static func setsCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.history.setsCount", defaultValue: "\(count) sets", bundle: .main,
            comment: "plain. Number of sets in a workout.")
    }

    static let search = LocalizedStringResource(
        "plain.history.search", defaultValue: "Search workouts and exercises", bundle: .main,
        comment: "plain. Search field in the log.")

    static let filters = LocalizedStringResource(
        "plain.history.filters", defaultValue: "Filters", bundle: .main,
        comment: "plain. Menu of log filters.")

    static let allPlans = LocalizedStringResource(
        "plain.history.allPlans", defaultValue: "All plans", bundle: .main,
        comment: "plain. Log filter.")

    static let thisPlan = LocalizedStringResource(
        "plain.history.thisPlan", defaultValue: "This plan", bundle: .main,
        comment: "plain. Log filter: only the active plan.")

    static let anyTime = LocalizedStringResource(
        "plain.history.anyTime", defaultValue: "Any time", bundle: .main,
        comment: "plain. Log date filter.")

    static let lastMonth = LocalizedStringResource(
        "plain.history.lastMonth", defaultValue: "Last 4 weeks", bundle: .main,
        comment: "plain. Log date filter.")

    static let lastQuarter = LocalizedStringResource(
        "plain.history.lastQuarter", defaultValue: "Last 3 months", bundle: .main,
        comment: "plain. Log date filter.")

    static let lastYear = LocalizedStringResource(
        "plain.history.lastYear", defaultValue: "Last year", bundle: .main,
        comment: "plain. Log date filter.")

    static let noMatches = LocalizedStringResource(
        "plain.history.noMatches", defaultValue: "No workouts match.", bundle: .main,
        comment: "plain. Log is empty because of filters.")

    static let clearFilters = LocalizedStringResource(
        "plain.history.clearFilters", defaultValue: "Clear filters", bundle: .main,
        comment: "plain. Button.")

    static func fromPlanDay(week: Int, focus: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.history.fromPlanDay", defaultValue: "From your plan: week \(week), \(focus)", bundle: .main,
            comment: "plain. Which plan day a workout came from.")
    }

    static let offPlan = LocalizedStringResource(
        "plain.history.offPlan", defaultValue: "Off the plan", bundle: .main,
        comment: "plain. A workout that wasn't from a plan day.")

    static let delete = LocalizedStringResource(
        "plain.history.delete", defaultValue: "Delete workout", bundle: .main,
        comment: "plain. Button.")

    static let deleteSet = LocalizedStringResource(
        "plain.history.deleteSet", defaultValue: "Delete set", bundle: .main,
        comment: "plain. Button.")

    static let editSet = LocalizedStringResource(
        "plain.history.editSet", defaultValue: "Edit set", bundle: .main,
        comment: "plain. Title of the sheet that changes a past set.")

    static let editTitle = LocalizedStringResource(
        "plain.history.editTitle", defaultValue: "Name", bundle: .main,
        comment: "plain. Field for a workout's name.")

    static let started = LocalizedStringResource(
        "plain.history.started", defaultValue: "Started", bundle: .main,
        comment: "plain. Field for when a workout started.")

    static let healthDeleteFailed = LocalizedStringResource(
        "plain.history.healthDeleteFailed",
        defaultValue: "The workout is deleted here, but Health still has it. Remove it in the Health app.",
        bundle: .main, comment: "plain. Deleting the matching Health workout failed.")

    static let exerciseHistory = LocalizedStringResource(
        "plain.history.exerciseHistory", defaultValue: "Every set", bundle: .main,
        comment: "plain. Link to all logged sets for one exercise.")

    static let estimatedMaxTrend = LocalizedStringResource(
        "plain.history.estimatedMaxTrend", defaultValue: "Estimated 1RM", bundle: .main,
        comment: "plain. Chart title.")

}
