import Foundation

/// Strings only the Mac app shows (#17): the sidebar and the menu bar. All plain.
enum MacCopy {
    static let progress = LocalizedStringResource(
        "plain.mac.sidebar.progress", defaultValue: "Progress", bundle: .main,
        comment: "plain. Mac. Sidebar section and title of the progress charts.")

    static func daysPerWeek(_ days: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.mac.sidebar.daysPerWeek", defaultValue: "\(days) days a week", bundle: .main,
            comment: "plain. Mac. Sidebar footer: how many days a week the person trains.")
    }

    static let newWorkout = LocalizedStringResource(
        "plain.mac.menu.newWorkout", defaultValue: "New Workout", bundle: .main,
        comment: "plain. Mac. File menu: start today's session, or a workout off the plan.")

    static let findInLog = LocalizedStringResource(
        "plain.mac.menu.findInLog", defaultValue: "Find in Log", bundle: .main,
        comment: "plain. Mac. Edit menu: put the cursor in the log's search field.")

    static let done = LocalizedStringResource(
        "plain.done", defaultValue: "Done", bundle: .main, comment: "plain. Button.")

    static let planGrid = LocalizedStringResource(
        "plain.mac.plan.grid", defaultValue: "Week grid", bundle: .main,
        comment: "plain. Mac. Show the plan as a grid of weeks and days.")

    static let planList = LocalizedStringResource(
        "plain.mac.plan.list", defaultValue: "List", bundle: .main,
        comment: "plain. Mac. Show the plan as a list, like on iPhone.")

    static let planLayout = LocalizedStringResource(
        "plain.mac.plan.layout", defaultValue: "Plan layout", bundle: .main,
        comment: "plain. Mac. Label of the control that switches between the week grid and the list.")
}
