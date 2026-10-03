import Foundation

/// Strings for reading and editing a plan (#10). Plain throughout, except reworking and
/// rebrewing, which use the voice (#3).
public enum PlanCopy {
    static let thisWeek = LocalizedStringResource(
        "plain.plan.thisWeek", defaultValue: "This week", bundle: .main,
        comment: "plain. Badge on the current week.")

    static let edit = LocalizedStringResource(
        "plain.edit", defaultValue: "Edit", bundle: .main,
        comment: "plain. Button.")

    static let done = LocalizedStringResource(
        "plain.done", defaultValue: "Done", bundle: .main,
        comment: "plain. Button.")

    static let undo = LocalizedStringResource(
        "plain.undo", defaultValue: "Undo", bundle: .main,
        comment: "plain. Button.")

    static let redo = LocalizedStringResource(
        "plain.redo", defaultValue: "Redo", bundle: .main,
        comment: "plain. Button.")

    static let addExercise = LocalizedStringResource(
        "plain.addExercise", defaultValue: "Add exercise", bundle: .main,
        comment: "plain. Button.")

    static let swap = LocalizedStringResource(
        "plain.swap", defaultValue: "Swap", bundle: .main,
        comment: "plain. Swap an exercise for a similar one.")

    static func swapTitle(_ name: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.swapTitle", defaultValue: "Swap \(name)", bundle: .main,
            comment: "plain. Title of the swap picker.")
    }

    static let similar = LocalizedStringResource(
        "plain.similar", defaultValue: "Similar exercises", bundle: .main,
        comment: "plain. Section in the swap picker.")

    static let searchAll = LocalizedStringResource(
        "plain.searchAll", defaultValue: "Search everything", bundle: .main,
        comment: "plain. Open the full exercise picker.")

    static let remove = LocalizedStringResource(
        "plain.remove", defaultValue: "Remove", bundle: .main,
        comment: "plain. Remove an exercise from a day.")

    static let addSet = LocalizedStringResource(
        "plain.addSet", defaultValue: "Add set", bundle: .main,
        comment: "plain. Button.")

    static let removeSet = LocalizedStringResource(
        "plain.removeSet", defaultValue: "Remove last set", bundle: .main,
        comment: "plain. Button.")

    static let moveDay = LocalizedStringResource(
        "plain.moveDay", defaultValue: "Day of the week", bundle: .main,
        comment: "plain. Picker to move a session to another weekday.")

    static func setNumber(_ number: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.setNumber", defaultValue: "Set \(number)", bundle: .main,
            comment: "plain. Set heading.")
    }

    static let reps = LocalizedStringResource(
        "plain.target.reps", defaultValue: "Reps", bundle: .main,
        comment: "plain. Target field.")

    static let load = LocalizedStringResource(
        "plain.target.load", defaultValue: "Weight", bundle: .main,
        comment: "plain. Target field.")

    static let seconds = LocalizedStringResource(
        "plain.target.seconds", defaultValue: "Seconds", bundle: .main,
        comment: "plain. Target field.")

    static let meters = LocalizedStringResource(
        "plain.target.meters", defaultValue: "Metres", bundle: .main,
        comment: "plain. Target field.")

    static let rpe = LocalizedStringResource(
        "plain.target.rpe", defaultValue: "Effort (RPE)", bundle: .main,
        comment: "plain. Target field.")

    static let rest = LocalizedStringResource(
        "plain.target.rest", defaultValue: "Rest (seconds)", bundle: .main,
        comment: "plain. Target field.")

    static let rounds = LocalizedStringResource(
        "plain.target.rounds", defaultValue: "Rounds", bundle: .main,
        comment: "plain. Target field.")

    static let applyToAll = LocalizedStringResource(
        "plain.applyToAll", defaultValue: "Apply to every set", bundle: .main,
        comment: "plain. Toggle when editing targets.")

    static let targets = LocalizedStringResource(
        "plain.targets", defaultValue: "Targets", bundle: .main,
        comment: "plain. Section heading.")

    static let howTo = LocalizedStringResource(
        "plain.howTo", defaultValue: "How to do it", bundle: .main,
        comment: "plain. Exercise cues heading.")

    static let watchFor = LocalizedStringResource(
        "plain.watchFor", defaultValue: "Watch for", bundle: .main,
        comment: "plain. Common mistakes heading.")

    static let superset = LocalizedStringResource(
        "plain.superset", defaultValue: "Superset", bundle: .main,
        comment: "plain. Label on exercises done back to back.")

    static let emptyDay = LocalizedStringResource(
        "plain.emptyDay", defaultValue: "No exercises yet. Add one, or rework the day.", bundle: .main,
        comment: "plain. Empty plan day.")

    static let edited = LocalizedStringResource(
        "plain.edited", defaultValue: "Edited", bundle: .main,
        comment: "plain. Badge on a day changed by hand.")

    static let reworkPrompt = LocalizedStringResource(
        "voice.rework.prompt", defaultValue: "What should change? e.g. no barbell today, only 30 minutes, knee's sore",
        bundle: .main,
        comment: "voice. Rework this day text field.")

    static let reworking = LocalizedStringResource(
        "voice.rework.working", defaultValue: "Reworking the day…", bundle: .main,
        comment: "voice. Shown while the AI reworks a day.")

    static let reworkGo = LocalizedStringResource(
        "voice.rework.go", defaultValue: "Rework", bundle: .main,
        comment: "voice. Button that starts a rework.")

    static let useThis = LocalizedStringResource(
        "plain.rework.accept", defaultValue: "Use this", bundle: .main,
        comment: "plain. Accept a reworked day.")

    static let keepOriginal = LocalizedStringResource(
        "plain.rework.discard", defaultValue: "Keep the original", bundle: .main,
        comment: "plain. Discard a reworked day.")

    static let before = LocalizedStringResource(
        "plain.rework.before", defaultValue: "Before", bundle: .main,
        comment: "plain. Diff column.")

    static let after = LocalizedStringResource(
        "plain.rework.after", defaultValue: "After", bundle: .main,
        comment: "plain. Diff column.")

    static let added = LocalizedStringResource(
        "plain.rework.added", defaultValue: "Added", bundle: .main,
        comment: "plain. Diff marker for a new exercise.")

    static let removed = LocalizedStringResource(
        "plain.rework.removed", defaultValue: "Removed", bundle: .main,
        comment: "plain. Diff marker for a dropped exercise.")

    static let kept = LocalizedStringResource(
        "plain.rework.kept", defaultValue: "Kept", bundle: .main,
        comment: "plain. Diff marker for an unchanged exercise.")

    static func rebrewFrom(_ week: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.rebrew.from", defaultValue: "From week \(week)", bundle: .main,
            comment: "plain. Rebrew week stepper.")
    }

    static let keepEdits = LocalizedStringResource(
        "plain.rebrew.keepEdits", defaultValue: "Keep days I changed", bundle: .main,
        comment: "plain. Rebrew toggle.")

    static let rebrewNote = LocalizedStringResource(
        "plain.rebrew.note", defaultValue: "Days you've already logged always stay, with their history.", bundle: .main,
        comment: "plain. Under the rebrew options.")

    static func rebrewing(_ week: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.rebrew.working", defaultValue: "Rebrewing from week \(week)…", bundle: .main,
            comment: "voice. Shown while rebrewing.")
    }

    static let plans = LocalizedStringResource(
        "plain.plans", defaultValue: "Plans", bundle: .main,
        comment: "plain. Plan history title.")

    static let active = LocalizedStringResource(
        "plain.plans.active", defaultValue: "Active", bundle: .main,
        comment: "plain. Badge on the active plan.")

    static let makeActive = LocalizedStringResource(
        "plain.plans.makeActive", defaultValue: "Make active", bundle: .main,
        comment: "plain. Button on an archived plan.")

    static let earlierPlans = LocalizedStringResource(
        "plain.plans.earlier", defaultValue: "Earlier plans", bundle: .main,
        comment: "plain. Archived plans section.")

    static let newPlan = LocalizedStringResource(
        "voice.plans.new", defaultValue: "Brew a new plan", bundle: .main,
        comment: "voice. Start a new plan from the history screen.")

    static let whatsThis = LocalizedStringResource(
        "plain.whatsThis", defaultValue: "What's this?", bundle: .main,
        comment: "plain. Opens a plain explanation of a term.")

    static let rpeTerm = LocalizedStringResource(
        "plain.glossary.rpeTerm", defaultValue: "RPE", bundle: .main,
        comment: "plain. Glossary term.")

    public static let rpeHelp = LocalizedStringResource(
        "plain.glossary.rpe",
        defaultValue:
            "RPE is how hard a set feels, from 1 to 10. At 8 you could do about two more reps with good form.",
        bundle: .main,
        comment: "plain. Glossary.")

    static let oneRepMaxTerm = LocalizedStringResource(
        "plain.glossary.oneRepMaxTerm", defaultValue: "1RM", bundle: .main,
        comment: "plain. Glossary term.")

    public static let oneRepMaxHelp = LocalizedStringResource(
        "plain.glossary.oneRepMax",
        defaultValue: "1RM is the most you could lift once. Plans can set weights as a percentage of it.",
        bundle: .main,
        comment: "plain. Glossary.")

    static let supersetHelp = LocalizedStringResource(
        "plain.glossary.superset", defaultValue: "A superset pairs two exercises back to back, then you rest.",
        bundle: .main,
        comment: "plain. Glossary.")

    static let deloadTerm = LocalizedStringResource(
        "plain.glossary.deloadTerm", defaultValue: "Deload", bundle: .main,
        comment: "plain. Glossary term.")

    static let deloadHelp = LocalizedStringResource(
        "plain.glossary.deload",
        defaultValue: "A deload is a lighter week so your body can recover and come back stronger.", bundle: .main,
        comment: "plain. Glossary.")

    static let session = LocalizedStringResource(
        "plain.session", defaultValue: "Session", bundle: .main,
        comment: "plain. Day detail section.")

    static let logged = LocalizedStringResource(
        "plain.logged", defaultValue: "Logged", bundle: .main,
        comment: "plain. A plan day that has a logged workout.")

    static let cuesFromLibrary = LocalizedStringResource(
        "plain.fromYourPlan", defaultValue: "From your plan", bundle: .main,
        comment: "plain. Label before the day's one-line reason.")
}
