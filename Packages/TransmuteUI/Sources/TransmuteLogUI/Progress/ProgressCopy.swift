import Foundation

/// Strings for Progress (#16). Titles and figures stay plain; the weekly summary's title and
/// the streak use the voice (#3).
public enum ProgressCopy {
    public static let title = LocalizedStringResource(
        "plain.progress.title", defaultValue: "Progress", bundle: .main,
        comment: "plain. Tab and title of the Progress screen.")

    static let empty = LocalizedStringResource(
        "plain.progress.empty", defaultValue: "Log a workout and your progress shows up here.", bundle: .main,
        comment: "plain. Progress has nothing to chart yet.")

    // MARK: Figures

    static let thisWeek = LocalizedStringResource(
        "plain.progress.thisWeek", defaultValue: "This week", bundle: .main,
        comment: "plain. Heading over this week's figures.")

    static let sessions = LocalizedStringResource(
        "plain.progress.sessions", defaultValue: "Sessions", bundle: .main,
        comment: "plain. Figure: sessions done out of planned this week.")

    static func sessionsValue(_ done: Int, of planned: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progress.sessionsValue", defaultValue: "\(done) of \(planned)", bundle: .main,
            comment: "plain. Sessions done out of planned, e.g. 2 of 4.")
    }

    static let volume = LocalizedStringResource(
        "plain.progress.volume", defaultValue: "Volume", bundle: .main,
        comment: "plain. Figure: total weight lifted this week.")

    static let bodyweight = LocalizedStringResource(
        "plain.progress.bodyweight", defaultValue: "Bodyweight", bundle: .main,
        comment: "plain. Figure and chart title.")

    static func versusLastWeek(_ change: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progress.versusLastWeek", defaultValue: "\(change) vs last week", bundle: .main,
            comment: "plain. Change under a figure, e.g. +6% vs last week.")
    }

    static func sincePlanStart(_ change: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progress.sincePlanStart", defaultValue: "\(change) this plan", bundle: .main,
            comment: "plain. Change under a figure since the plan started, e.g. +2.5 kg this plan.")
    }

    static let estimatedMax = LocalizedStringResource(
        "plain.history.estimatedMaxTrend", defaultValue: "Estimated 1RM", bundle: .main,
        comment: "plain. Chart title.")

    static let estimatedMaxHelp = LocalizedStringResource(
        "plain.progress.estimatedMaxHelp",
        defaultValue: "The most you could likely lift once, worked out from your sets. Gold points are records.",
        bundle: .main, comment: "plain. Explains estimated 1RM under its chart, for a beginner.")

    // MARK: Charts

    static let weeklyVolume = LocalizedStringResource(
        "plain.progress.weeklyVolume", defaultValue: "Weekly volume", bundle: .main,
        comment: "plain. Chart title: weight lifted per week.")

    static let byCategory = LocalizedStringResource(
        "plain.progress.byCategory", defaultValue: "By type", bundle: .main,
        comment: "plain. Split the volume chart by kind of training.")

    static let byMuscle = LocalizedStringResource(
        "plain.progress.byMuscle", defaultValue: "By muscle", bundle: .main,
        comment: "plain. Split the volume chart by muscle group.")

    static let split = LocalizedStringResource(
        "plain.progress.split", defaultValue: "Split", bundle: .main,
        comment: "plain. Label of the control that picks how the volume chart is split.")

    static let lift = LocalizedStringResource(
        "plain.progress.lift", defaultValue: "Lift", bundle: .main,
        comment: "plain. Label of the control that picks which lift's chart to show.")

    static let week = LocalizedStringResource(
        "plain.progress.week", defaultValue: "Week", bundle: .main,
        comment: "plain. Chart axis.")

    static let date = LocalizedStringResource(
        "plain.progress.date", defaultValue: "Date", bundle: .main,
        comment: "plain. Chart axis.")

    static let trend = LocalizedStringResource(
        "plain.progress.trend", defaultValue: "7-day average", bundle: .main,
        comment: "plain. The smoothed line on the bodyweight chart.")

    static let other = LocalizedStringResource(
        "plain.progress.other", defaultValue: "Other", bundle: .main,
        comment: "plain. Volume chart legend: the smaller groups together.")

    static let conditioning = LocalizedStringResource(
        "plain.progress.conditioning", defaultValue: "Conditioning", bundle: .main,
        comment: "plain. Chart section for intervals, sprints and holds.")

    static let rounds = LocalizedStringResource(
        "plain.progress.rounds", defaultValue: "Rounds", bundle: .main,
        comment: "plain. Conditioning measure: rounds completed.")

    static let pace = LocalizedStringResource(
        "plain.progress.pace", defaultValue: "Seconds per 100 m (lower is faster)", bundle: .main,
        comment: "plain. Conditioning measure: pace.")

    static let longestTime = LocalizedStringResource(
        "plain.progress.longestTime", defaultValue: "Longest, in seconds", bundle: .main,
        comment: "plain. Conditioning measure: longest hold or effort.")

    static let mostReps = LocalizedStringResource(
        "plain.progress.mostReps", defaultValue: "Most reps in a set", bundle: .main,
        comment: "plain. Conditioning measure.")

    // MARK: Adherence

    static let adherence = LocalizedStringResource(
        "plain.progress.adherence", defaultValue: "Planned and done", bundle: .main,
        comment: "plain. Chart title: sessions planned and done per week.")

    static let planned = LocalizedStringResource(
        "plain.progress.planned", defaultValue: "Planned", bundle: .main,
        comment: "plain. Chart series: sessions planned.")

    static let done = LocalizedStringResource(
        "plain.progress.done", defaultValue: "Done", bundle: .main,
        comment: "plain. Chart series: sessions done.")

    static func planWeek(_ week: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.progress.planWeek", defaultValue: "Week \(week)", bundle: .main,
            comment: "plain. A plan week on a chart axis, e.g. Week 3.")
    }

    static let streakHelp = LocalizedStringResource(
        "plain.progress.streakHelp",
        defaultValue: "Weeks in a row with every planned session done. Lighter weeks count.", bundle: .main,
        comment: "plain. Explains the streak.")

    // MARK: Summary

    static let reworkNextWeek = LocalizedStringResource(
        "voice.progress.reworkNextWeek", defaultValue: "Rework next week", bundle: .main,
        comment: "voice. Under the weekly summary when lifts stalled: rework the next session with AI.")

    static let writtenOnDevice = LocalizedStringResource(
        "plain.progress.writtenOnDevice", defaultValue: "Written on this device by Apple Intelligence.",
        bundle: .main, comment: "plain. Under an AI-written weekly summary.")

    static let records = LocalizedStringResource(
        "plain.records.title", defaultValue: "Records", bundle: .main,
        comment: "plain. Title of the records screen.")
}
