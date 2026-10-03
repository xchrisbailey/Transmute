import Foundation

/// Strings for Today and the workout session (#11). Mid-set everything stays plain; only the
/// rest-day and done lines use the voice (#3).
public enum LogCopy {
    // MARK: Tabs

    public static let today = LocalizedStringResource(
        "plain.today.title", defaultValue: "Today", bundle: .main,
        comment: "plain. Tab and title of the Today screen.")

    public static let plan = LocalizedStringResource(
        "plain.tab.plan", defaultValue: "Plan", bundle: .main,
        comment: "plain. Tab for the plan.")

    // MARK: Today

    static func eyebrow(week: Int, day: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.today.eyebrow", defaultValue: "WEEK \(week) · DAY \(day)", bundle: .main,
            comment: "plain. Above today's session name, e.g. WEEK 3 · DAY 1. Upper case.")
    }

    static let restDay = LocalizedStringResource(
        "plain.today.restDay", defaultValue: "Rest day", bundle: .main,
        comment: "plain. Today has no session.")

    static let restDayBody = LocalizedStringResource(
        "voice.today.restDay", defaultValue: "Nothing in the crucible today. Let the work settle.", bundle: .main,
        comment: "voice. Under the rest day title.")

    static func next(_ focus: String, on weekday: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.today.next", defaultValue: "Next: \(focus) on \(weekday)", bundle: .main,
            comment: "plain. The next session, e.g. Next: Lower A on Thursday.")
    }

    static let doneToday = LocalizedStringResource(
        "voice.today.done", defaultValue: "Today's work is done.", bundle: .main,
        comment: "voice. Today's session is already logged.")

    static let planEnded = LocalizedStringResource(
        "plain.today.planEnded", defaultValue: "This plan has no more sessions. Brew a new one from Plan.",
        bundle: .main, comment: "plain. Every planned day is in the past.")

    static let logWorkout = LocalizedStringResource(
        "plain.today.logWorkout", defaultValue: "Log a workout", bundle: .main,
        comment: "plain. Start a workout that isn't on the plan.")

    static let resume = LocalizedStringResource(
        "plain.today.resume", defaultValue: "Resume workout", bundle: .main,
        comment: "plain. Go back to a workout in progress.")

    static let adHocTitle = LocalizedStringResource(
        "plain.today.adHocTitle", defaultValue: "Workout", bundle: .main,
        comment: "plain. Default name of a workout logged off the plan.")

    static let fromYourPlan = LocalizedStringResource(
        "plain.today.fromYourPlan", defaultValue: "From your plan", bundle: .main,
        comment: "plain. Label before the reason targets changed.")

    // MARK: Session

    static let set = LocalizedStringResource(
        "plain.session.set", defaultValue: "Set", bundle: .main,
        comment: "plain. Column heading in the set table.")

    static let reps = LocalizedStringResource(
        "plain.session.reps", defaultValue: "Reps", bundle: .main,
        comment: "plain. Column heading in the set table.")

    static let time = LocalizedStringResource(
        "plain.session.time", defaultValue: "Time", bundle: .main,
        comment: "plain. Column heading in the set table.")

    static let distance = LocalizedStringResource(
        "plain.session.distance", defaultValue: "Distance", bundle: .main,
        comment: "plain. Column heading in the set table.")

    static let rounds = LocalizedStringResource(
        "plain.session.rounds", defaultValue: "Rounds", bundle: .main,
        comment: "plain. Column heading in the set table.")

    static let weight = LocalizedStringResource(
        "plain.session.weight", defaultValue: "Weight", bundle: .main,
        comment: "plain. Field label for a set's load.")

    static let seconds = LocalizedStringResource(
        "plain.session.seconds", defaultValue: "Seconds", bundle: .main,
        comment: "plain. Field label.")

    static let meters = LocalizedStringResource(
        "plain.session.meters", defaultValue: "Metres", bundle: .main,
        comment: "plain. Field label.")

    static let rpe = LocalizedStringResource(
        "plain.session.rpe", defaultValue: "RPE (optional)", bundle: .main,
        comment: "plain. Field label for how hard the set felt, 1 to 10.")

    static let warmUp = LocalizedStringResource(
        "plain.session.warmUp", defaultValue: "Warm-up", bundle: .main,
        comment: "plain. Marks a warm-up set.")

    static func setOf(_ number: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.setOf", defaultValue: "Set \(number) of \(total)", bundle: .main,
            comment: "plain. Which set this is, e.g. Set 2 of 4.")
    }

    static func repsCount(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.repsCount", defaultValue: "\(count) reps", bundle: .main,
            comment: "plain. VoiceOver, e.g. 5 reps.")
    }

    static let logged = LocalizedStringResource(
        "plain.session.logged", defaultValue: "Logged", bundle: .main,
        comment: "plain. VoiceOver value for a set that's checked off.")

    static let notLogged = LocalizedStringResource(
        "plain.session.notLogged", defaultValue: "Not logged", bundle: .main,
        comment: "plain. VoiceOver value for a set that isn't checked off.")

    static let current = LocalizedStringResource(
        "plain.session.current", defaultValue: "Current set", bundle: .main,
        comment: "plain. VoiceOver hint for the set to do next.")

    static let undoSet = LocalizedStringResource(
        "plain.session.undoSet", defaultValue: "Undo log", bundle: .main,
        comment: "plain. Take back a logged set.")

    static let skip = LocalizedStringResource(
        "plain.session.skip", defaultValue: "Skip exercise", bundle: .main,
        comment: "plain. Pass over an exercise mid-workout.")

    static let unskip = LocalizedStringResource(
        "plain.session.unskip", defaultValue: "Bring back", bundle: .main,
        comment: "plain. Undo skipping an exercise.")

    static let skipped = LocalizedStringResource(
        "plain.session.skipped", defaultValue: "Skipped", bundle: .main,
        comment: "plain. Badge on a skipped exercise.")

    static let substitute = LocalizedStringResource(
        "plain.session.substitute", defaultValue: "Substitute", bundle: .main,
        comment: "plain. Swap an exercise mid-workout.")

    static func substitutedFor(_ name: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.substitutedFor", defaultValue: "Instead of \(name)", bundle: .main,
            comment: "plain. Under a substituted exercise, e.g. Instead of Back squat.")
    }

    static let addExercise = LocalizedStringResource(
        "plain.addExercise", defaultValue: "Add exercise", bundle: .main,
        comment: "plain. Button.")

    static let addSet = LocalizedStringResource(
        "plain.addSet", defaultValue: "Add set", bundle: .main,
        comment: "plain. Button.")

    static let removeSet = LocalizedStringResource(
        "plain.session.removeSet", defaultValue: "Remove set", bundle: .main,
        comment: "plain. Remove an unlogged set.")

    static let notes = LocalizedStringResource(
        "plain.session.notes", defaultValue: "Notes", bundle: .main,
        comment: "plain. Notes on an exercise or set.")

    static let workoutNotes = LocalizedStringResource(
        "plain.session.workoutNotes", defaultValue: "Workout notes", bundle: .main,
        comment: "plain. Notes on the whole workout.")

    static func setNote(_ number: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.setNote", defaultValue: "Note for set \(number)", bundle: .main,
            comment: "plain. Title of the note editor for one set.")
    }

    static let finish = LocalizedStringResource(
        "plain.session.finish", defaultValue: "Finish", bundle: .main,
        comment: "plain. End the workout.")

    static let finishConfirm = LocalizedStringResource(
        "plain.session.finishConfirm", defaultValue: "Finish the workout? Sets you haven't logged won't be saved.",
        bundle: .main, comment: "plain. Confirm finishing with sets left.")

    static let discard = LocalizedStringResource(
        "plain.session.discard", defaultValue: "Discard workout", bundle: .main,
        comment: "plain. Throw away the workout in progress.")

    static let discardConfirm = LocalizedStringResource(
        "plain.session.discardConfirm", defaultValue: "Discard this workout? Nothing from it will be saved.",
        bundle: .main, comment: "plain. Confirm discarding a workout in progress.")

    static let keepGoing = LocalizedStringResource(
        "plain.session.keepGoing", defaultValue: "Keep going", bundle: .main,
        comment: "plain. Cancel finishing or discarding.")

    static let minimise = LocalizedStringResource(
        "plain.session.minimise", defaultValue: "Hide workout", bundle: .main,
        comment: "plain. Close the session screen; the workout keeps running.")

    static let allLogged = LocalizedStringResource(
        "plain.session.allLogged", defaultValue: "Every set is logged.", bundle: .main,
        comment: "plain. Nothing left to do but finish.")

    static let more = LocalizedStringResource(
        "plain.session.more", defaultValue: "More", bundle: .main,
        comment: "plain. Menu of exercise actions.")

    // MARK: Rest and timers

    static let skipRest = LocalizedStringResource(
        "plain.session.skipRest", defaultValue: "Skip rest", bundle: .main,
        comment: "plain. End the rest timer early.")

    static let restOver = LocalizedStringResource(
        "plain.session.restOver", defaultValue: "Rest's up", bundle: .main,
        comment: "plain. The rest timer finished.")

    static func restOverNext(_ exercise: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.restOverNext", defaultValue: "Rest's up. Next: \(exercise).", bundle: .main,
            comment: "plain. Notification when rest ends with the app in the background.")
    }

    static let addRest = LocalizedStringResource(
        "plain.session.addRest", defaultValue: "15 seconds more rest", bundle: .main,
        comment: "plain. VoiceOver label for the +15 s button.")

    static let lessRest = LocalizedStringResource(
        "plain.session.lessRest", defaultValue: "15 seconds less rest", bundle: .main,
        comment: "plain. VoiceOver label for the −15 s button.")

    static let start = LocalizedStringResource(
        "plain.session.startTimer", defaultValue: "Start timer", bundle: .main,
        comment: "plain. Start a timed set or intervals.")

    static let stop = LocalizedStringResource(
        "plain.session.stopTimer", defaultValue: "Stop timer", bundle: .main,
        comment: "plain. Stop a timed set or intervals.")

    static let work = LocalizedStringResource(
        "plain.session.work", defaultValue: "Work", bundle: .main,
        comment: "plain. Interval phase.")

    static let intervalRest = LocalizedStringResource(
        "plain.session.intervalRest", defaultValue: "Rest", bundle: .main,
        comment: "plain. Interval phase.")

    static func round(_ number: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.round", defaultValue: "Round \(number) of \(total)", bundle: .main,
            comment: "plain. Interval progress, e.g. Round 3 of 8.")
    }

    // MARK: Finish

    static let sets = LocalizedStringResource(
        "plain.finish.sets", defaultValue: "Sets", bundle: .main,
        comment: "plain. Summary figure.")

    static let volume = LocalizedStringResource(
        "plain.finish.volume", defaultValue: "Volume", bundle: .main,
        comment: "plain. Summary figure: total weight lifted.")

    static let duration = LocalizedStringResource(
        "plain.finish.duration", defaultValue: "Time", bundle: .main,
        comment: "plain. Summary figure.")

    static let save = LocalizedStringResource(
        "plain.finish.save", defaultValue: "Save", bundle: .main,
        comment: "plain. Close the finished workout's summary.")

    static let savedToHealth = LocalizedStringResource(
        "plain.finish.savedToHealth", defaultValue: "Saved to Health", bundle: .main,
        comment: "plain. The workout was written to Health.")

    static let healthFailed = LocalizedStringResource(
        "plain.finish.healthFailed", defaultValue: "Couldn't save to Health. The workout is saved in Transmute.",
        bundle: .main, comment: "plain. Writing to Health failed.")

    static func workDone(sets: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "voice.finish.workDoneNoLoad", defaultValue: "The work is done. \(sets) sets.", bundle: .main,
            comment: "voice. Workout finished with no weighted sets, so no volume to show.")
    }

    // MARK: Records and plates

    // MARK: Apple Watch

    static let onWatch = LocalizedStringResource(
        "plain.session.onWatch", defaultValue: "Running on Apple Watch", bundle: .main,
        comment: "plain. The workout was started on the watch and is being followed on iPhone.")

    static let finishedOnWatch = LocalizedStringResource(
        "plain.session.finishedOnWatch", defaultValue: "Finished. It's saved from your Apple Watch.", bundle: .main,
        comment: "plain. A workout run on the watch has ended.")

    static let done = LocalizedStringResource(
        "plain.done", defaultValue: "Done", bundle: .main,
        comment: "plain. Button.")

    static func heartRate(_ bpm: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.heartRate", defaultValue: "Heart rate, \(bpm) beats per minute", bundle: .main,
            comment: "plain. VoiceOver label for the heart rate the watch is reading.")
    }

    static let bigJump = LocalizedStringResource(
        "plain.session.bigJump", defaultValue: "That's far beyond your best. Is it right?", bundle: .main,
        comment: "plain. A logged set is suspiciously bigger than the previous record.")

    static let itsRight = LocalizedStringResource(
        "plain.session.itsRight", defaultValue: "Yes, it's right", bundle: .main,
        comment: "plain. Confirm a suspiciously big set.")

    static let fixIt = LocalizedStringResource(
        "plain.session.fixIt", defaultValue: "Fix it", bundle: .main,
        comment: "plain. Reopen a suspiciously big set to correct it.")

    static let plates = LocalizedStringResource(
        "plain.session.plates", defaultValue: "Plates", bundle: .main,
        comment: "plain. Open the plate calculator for a set.")

    static let records = LocalizedStringResource(
        "plain.records.title", defaultValue: "Records", bundle: .main, comment: "plain. Records screen title.")

    static let turnedToGold = LocalizedStringResource(
        "voice.finish.gold", defaultValue: "Turned to gold", bundle: .main,
        comment: "voice. Records set in the workout just finished.")
}
