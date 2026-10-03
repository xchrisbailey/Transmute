/// Every sentence the template summary can say, in one place so it can move to a String
/// Catalog later. A light week is described by what was done, never as a shortfall.
enum WeekSummaryCopy {
    /// How many items of a list a sentence names before it says "and N more".
    static let listLimit = 3

    static let quietHeadline = "A quiet week."
    static let recordsHeadline = "A week turned to gold."
    static let fullWeekHeadline = "A full week, distilled."
    static let headline = "This week, distilled."

    static let nothingLogged = "Nothing was logged this week, and rest counts too."
    static let readyWhenYouAre = "Your next session is ready whenever you are."
    static let keepGoing = "Every session you log sharpens next week's picture."

    static func sessions(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }

    static func adherence(done: Int, planned: Int) -> String {
        if planned <= 0 { return "You logged \(sessions(done))." }
        if done > planned { return "You did \(sessions(done)), more than the \(planned) planned." }
        if done == planned {
            return planned == 1 ? "You did your planned session." : "You did all \(planned) planned sessions."
        }
        return "You got \(done) of \(planned) planned sessions in."
    }

    static func volume(_ volume: String, changePercent: Int?) -> String {
        guard let changePercent else { return "Total volume was \(volume)." }
        if changePercent > 0 { return "Total volume was \(volume), up \(changePercent)% on last week." }
        if changePercent < 0 { return "Total volume was \(volume), down \(-changePercent)% on last week." }
        return "Total volume was \(volume), level with last week."
    }

    static func records(_ records: [String]) -> String {
        "\(records.count == 1 ? "New record" : "New records"): \(list(records, separator: "; "))."
    }

    static func wentUp(_ items: [String]) -> String {
        "Moving up: \(list(items, separator: "; "))."
    }

    static func stalled(_ names: [String]) -> String {
        "Holding steady and ready for a fresh approach: \(list(names, separator: ", "))."
    }

    static func streak(weeks: Int) -> String {
        "That's \(weeks) weeks in a row with training logged."
    }

    static func list(_ items: [String], separator: String) -> String {
        let shown = items.prefix(listLimit).joined(separator: separator)
        let extra = items.count - listLimit
        return extra > 0 ? "\(shown)\(separator)and \(extra) more" : shown
    }
}
