import Foundation

/// Strings for the watch (#15). Everything on the wrist is plain: no alchemy verbs mid-set.
/// Keys shared with the iPhone's session screen are the same entries in the String Catalog.
enum WatchCopy {
    // MARK: Today

    static let today = LocalizedStringResource(
        "plain.today.title", defaultValue: "Today", bundle: .main,
        comment: "plain. Tab and title of the Today screen.")

    static let start = LocalizedStringResource(
        "plain.watch.start", defaultValue: "Start workout", bundle: .main,
        comment: "plain. Watch. Start today's session.")

    static let resume = LocalizedStringResource(
        "plain.today.resume", defaultValue: "Resume workout", bundle: .main,
        comment: "plain. Go back to a workout in progress.")

    static let restDay = LocalizedStringResource(
        "plain.today.restDay", defaultValue: "Rest day", bundle: .main,
        comment: "plain. Today has no session.")

    static func next(_ focus: String, on weekday: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.today.next", defaultValue: "Next: \(focus) on \(weekday)", bundle: .main,
            comment: "plain. The next session, e.g. Next: Lower A on Thursday.")
    }

    static let doneToday = LocalizedStringResource(
        "plain.watch.doneToday", defaultValue: "Today's workout is done.", bundle: .main,
        comment: "plain. Watch. Today's session is already logged.")

    static let planEnded = LocalizedStringResource(
        "plain.watch.planEnded", defaultValue: "No more sessions in this plan.", bundle: .main,
        comment: "plain. Watch. Every planned day is in the past.")

    static let noPlan = LocalizedStringResource(
        "plain.watch.noPlan", defaultValue: "No plan yet. Make one in Transmute on iPhone.", bundle: .main,
        comment: "plain. Watch. Nothing to show until a plan exists; the watch can't make plans.")

    // MARK: Set

    static func setOf(_ number: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.session.setOf", defaultValue: "Set \(number) of \(total)", bundle: .main,
            comment: "plain. Which set this is, e.g. Set 2 of 4.")
    }

    static let warmUp = LocalizedStringResource(
        "plain.session.warmUp", defaultValue: "Warm-up", bundle: .main,
        comment: "plain. A warm-up set.")

    static let weight = LocalizedStringResource(
        "plain.session.weight", defaultValue: "Weight", bundle: .main,
        comment: "plain. Field label.")

    static let reps = LocalizedStringResource(
        "plain.session.reps", defaultValue: "Reps", bundle: .main,
        comment: "plain. Set table column.")

    static let time = LocalizedStringResource(
        "plain.session.time", defaultValue: "Time", bundle: .main,
        comment: "plain. Set table column.")

    static let distance = LocalizedStringResource(
        "plain.session.distance", defaultValue: "Distance", bundle: .main,
        comment: "plain. Set table column.")

    static let crownHint = LocalizedStringResource(
        "plain.watch.crownHint", defaultValue: "Turn the Digital Crown to change it.", bundle: .main,
        comment: "plain. Watch. VoiceOver hint on a set's weight or reps.")

    static let allLogged = LocalizedStringResource(
        "plain.session.allLogged", defaultValue: "Every set is logged.", bundle: .main,
        comment: "plain. Nothing left to do but finish.")

    // MARK: Rest

    static let rest = LocalizedStringResource(
        "plain.session.intervalRest", defaultValue: "Rest", bundle: .main,
        comment: "plain. Interval phase.")

    static func nextSet(_ exercise: String) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.nextSet", defaultValue: "Next: \(exercise)", bundle: .main,
            comment: "plain. Watch. Under the rest ring, the exercise coming up, e.g. Next: Back squat.")
    }

    static let skipRest = LocalizedStringResource(
        "plain.session.skipRest", defaultValue: "Skip rest", bundle: .main,
        comment: "plain. End the rest timer early.")

    static let addRest = LocalizedStringResource(
        "plain.session.addRest", defaultValue: "15 seconds more rest", bundle: .main,
        comment: "plain. VoiceOver label for the +15 s button.")

    // MARK: Controls

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

    static let skipExercise = LocalizedStringResource(
        "plain.watch.skipExercise", defaultValue: "Skip exercise", bundle: .main,
        comment: "plain. Watch. Pass over the current exercise.")

    static let waterLock = LocalizedStringResource(
        "plain.watch.waterLock", defaultValue: "Lock screen", bundle: .main,
        comment: "plain. Watch. Turn on Water Lock so sweat and sleeves don't tap the screen.")

    static let waterLockHint = LocalizedStringResource(
        "plain.watch.waterLockHint", defaultValue: "Hold the Digital Crown to unlock.", bundle: .main,
        comment: "plain. Watch. Under the lock button.")

    // MARK: Exercises

    static let exercises = LocalizedStringResource(
        "plain.watch.exercises", defaultValue: "Exercises", bundle: .main,
        comment: "plain. Watch. Title of the list of this workout's exercises.")

    static func setsLogged(_ done: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.setsLogged", defaultValue: "\(done) of \(total) sets", bundle: .main,
            comment: "plain. Watch. How much of an exercise is logged, e.g. 2 of 5 sets.")
    }

    static let skipped = LocalizedStringResource(
        "plain.session.skipped", defaultValue: "Skipped", bundle: .main,
        comment: "plain. The exercise was passed over.")

    // MARK: Finish

    static let workoutDone = LocalizedStringResource(
        "plain.watch.workoutDone", defaultValue: "Workout done", bundle: .main,
        comment: "plain. Watch. Title of the summary after finishing.")

    static let sets = LocalizedStringResource(
        "plain.finish.sets", defaultValue: "Sets", bundle: .main,
        comment: "plain. Summary figure.")

    static let volume = LocalizedStringResource(
        "plain.finish.volume", defaultValue: "Volume", bundle: .main,
        comment: "plain. Summary figure: total weight lifted.")

    static let duration = LocalizedStringResource(
        "plain.finish.duration", defaultValue: "Time", bundle: .main,
        comment: "plain. Summary figure.")

    static let done = LocalizedStringResource(
        "plain.watch.done", defaultValue: "Done", bundle: .main,
        comment: "plain. Watch. Close the finished workout's summary.")

    // MARK: Health

    static let heartRate = LocalizedStringResource(
        "plain.watch.heartRate", defaultValue: "Heart rate", bundle: .main,
        comment: "plain. Watch. VoiceOver label for the live heart rate.")

    static func beatsPerMinute(_ count: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.watch.beatsPerMinute", defaultValue: "\(count) beats per minute", bundle: .main,
            comment: "plain. Watch. VoiceOver value for the live heart rate.")
    }

    static let averageHeartRate = LocalizedStringResource(
        "plain.watch.averageHeartRate", defaultValue: "Avg heart rate", bundle: .main,
        comment: "plain. Watch. Summary figure, in beats per minute.")

    static let energy = LocalizedStringResource(
        "plain.watch.energy", defaultValue: "Energy", bundle: .main,
        comment: "plain. Watch. Summary figure: active energy burned, in kilocalories.")

    static let savedToHealth = LocalizedStringResource(
        "plain.finish.savedToHealth", defaultValue: "Saved to Health", bundle: .main,
        comment: "plain. The workout was written to Health.")

    // MARK: Records

    static let newRecord = LocalizedStringResource(
        "plain.watch.newRecord", defaultValue: "New record", bundle: .main,
        comment: "plain. Watch. A set just beat a personal record.")

    static let bigJump = LocalizedStringResource(
        "plain.session.bigJump", defaultValue: "That's far beyond your best. Is it right?", bundle: .main,
        comment: "plain. A logged set is suspiciously bigger than the previous record.")

    static let itsRight = LocalizedStringResource(
        "plain.session.itsRight", defaultValue: "Yes, it's right", bundle: .main,
        comment: "plain. Confirm a suspiciously big set.")

    static let fixIt = LocalizedStringResource(
        "plain.session.fixIt", defaultValue: "Fix it", bundle: .main,
        comment: "plain. Reopen a suspiciously big set to correct it.")
}
