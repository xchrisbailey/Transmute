import Foundation

/// Strings for the parts of Settings that report on the system (#18): Apple Intelligence,
/// Health and iCloud. All plain.
enum SettingsStatusCopy {
    static let aiReady = LocalizedStringResource(
        "plain.settings.ai.ready",
        defaultValue: "Apple Intelligence is on and ready.",
        bundle: .main, comment: "plain. Status row.")

    static let aiOpenSettings = LocalizedStringResource(
        "plain.settings.ai.openSettings",
        defaultValue: "Open the device's Settings",
        bundle: .main,
        comment: "plain. Button: opens the system Settings app, where Apple Intelligence is turned on or off.")

    static let aiAlwaysOn = LocalizedStringResource(
        "plain.settings.ai.alwaysOn",
        defaultValue: """
            Transmute makes plans and weekly summaries with Apple Intelligence, so it can't be turned off here. \
            Logging workouts works without it.
            """,
        bundle: .main, comment: "plain. Explains why there's no switch for AI.")

    static let allowCloud = LocalizedStringResource(
        "plain.settings.ai.allowCloud",
        defaultValue: "Allow Private Cloud Compute",
        bundle: .main, comment: "plain. Toggle: let longer plans be made on Apple's Private Cloud Compute servers.")

    static let cloudOff = LocalizedStringResource(
        "plain.settings.ai.cloudOff",
        defaultValue: "Off: everything is done on this device. Nothing you enter leaves it to make a plan.",
        bundle: .main, comment: "plain. Footer when Private Cloud Compute is off.")

    static let cloudOn = LocalizedStringResource(
        "plain.settings.ai.cloudOn",
        defaultValue: """
            On: longer plans may be made on Private Cloud Compute, Apple's servers for Apple Intelligence. Transmute \
            then sends what the plan is made from: your measurements, goal, schedule, equipment, limitations and \
            recent training. Apple says these requests aren't stored and can't be read by Apple. It's free and needs \
            no account.
            """,
        bundle: .main, comment: "plain. Footer when Private Cloud Compute is on.")

    static let health = LocalizedStringResource(
        "plain.settings.health.title",
        defaultValue: "Health",
        bundle: .main, comment: "plain. Section heading.")

    static let healthSaving = LocalizedStringResource(
        "plain.settings.health.saving",
        defaultValue: "Saving to Health",
        bundle: .main, comment: "plain. Section heading: what Transmute may write.")

    static let healthReading = LocalizedStringResource(
        "plain.settings.health.reading",
        defaultValue: "Reading from Health",
        bundle: .main, comment: "plain. Section heading: what Transmute may read.")

    static let healthOnMac = LocalizedStringResource(
        "plain.settings.health.onMac",
        defaultValue: """
            There's no Health on the Mac. Bodyweight and workouts from Health reach this Mac from your iPhone \
            through iCloud.
            """,
        bundle: .main, comment: "plain. Mac. Shown instead of the Health permissions.")

    static let healthUnavailable = LocalizedStringResource(
        "plain.settings.health.unavailable",
        defaultValue: "Health isn't available on this device.",
        bundle: .main, comment: "plain. Shown instead of the Health permissions.")

    static let writeWorkouts = LocalizedStringResource(
        "plain.settings.health.write.workouts",
        defaultValue: "Workouts",
        bundle: .main, comment: "plain. Health data Transmute saves.")

    static let writeBodyweight = LocalizedStringResource(
        "plain.settings.health.write.bodyweight",
        defaultValue: "Bodyweight",
        bundle: .main, comment: "plain. Health data Transmute saves.")

    static let writeActiveEnergy = LocalizedStringResource(
        "plain.settings.health.write.activeEnergy",
        defaultValue: "Active energy",
        bundle: .main, comment: "plain. Health data Transmute saves: calories burned in a workout.")

    static let writeHeartRate = LocalizedStringResource(
        "plain.settings.health.write.heartRate",
        defaultValue: "Heart rate",
        bundle: .main, comment: "plain. Health data Transmute saves.")

    static let writeAllowed = LocalizedStringResource(
        "plain.settings.health.write.allowed",
        defaultValue: "Allowed",
        bundle: .main, comment: "plain. Health permission status.")

    static let writeDenied = LocalizedStringResource(
        "plain.settings.health.write.denied",
        defaultValue: "Not allowed",
        bundle: .main, comment: "plain. Health permission status.")

    static let notAsked = LocalizedStringResource(
        "plain.settings.health.notAsked",
        defaultValue: "Not asked yet",
        bundle: .main, comment: "plain. Health permission status: Transmute hasn't asked for this.")

    static let readProfile = LocalizedStringResource(
        "plain.settings.health.read.profile",
        defaultValue: "Height, weight, birth date and sex",
        bundle: .main, comment: "plain. Health data Transmute reads, for the profile.")

    static let readTrainingLoad = LocalizedStringResource(
        "plain.settings.health.read.trainingLoad",
        defaultValue: "Other workouts, resting heart rate and cardio fitness",
        bundle: .main, comment: "plain. Health data Transmute reads, to plan around the week.")

    static let readWorkouts = LocalizedStringResource(
        "plain.settings.health.read.workouts",
        defaultValue: "Heart rate and energy during a workout",
        bundle: .main, comment: "plain. Health data Transmute reads while a workout runs.")

    static let readAsked = LocalizedStringResource(
        "plain.settings.health.read.asked",
        defaultValue: "Asked",
        bundle: .main, comment: "plain. Health permission status: the person was asked, the answer isn't known.")

    static let readUnknown = LocalizedStringResource(
        "plain.settings.health.read.unknown",
        defaultValue: "Health couldn't say",
        bundle: .main, comment: "plain. Health permission status.")

    static let readNote = LocalizedStringResource(
        "plain.settings.health.read.note",
        defaultValue: """
            Health keeps your answer private: it tells Transmute that you were asked, never whether you said yes. \
            Transmute asks the first time a feature needs something, and works without it.
            """,
        bundle: .main, comment: "plain. Footer under the Health read rows.")

    static let openHealth = LocalizedStringResource(
        "plain.settings.health.open",
        defaultValue: "Open the Health app",
        bundle: .main, comment: "plain. Button.")

    static let healthChangeNote = LocalizedStringResource(
        "plain.settings.health.changeNote",
        defaultValue: """
            To change what Transmute can use: in the Health app, tap your picture, then Apps, then Transmute.
            """,
        bundle: .main, comment: "plain. Footer under the Open the Health app button.")

    static let cloud = LocalizedStringResource(
        "plain.settings.icloud.title",
        defaultValue: "iCloud sync",
        bundle: .main, comment: "plain. Section heading.")

    static let cloudAvailable = LocalizedStringResource(
        "plain.settings.icloud.available",
        defaultValue: """
            iCloud sync is on. Your profile, plans and workouts are kept in your own iCloud and shared with your \
            other devices.
            """,
        bundle: .main, comment: "plain. iCloud status.")

    static let cloudNotSyncing = LocalizedStringResource(
        "plain.settings.icloud.notSyncing",
        defaultValue: """
            iCloud sync is off in this copy of Transmute, because it wasn't signed for iCloud. Everything stays on \
            this device.
            """,
        bundle: .main, comment: "plain. iCloud status: an unsigned or local build.")

    static let cloudSignedOut = LocalizedStringResource(
        "plain.settings.icloud.signedOut",
        defaultValue: """
            iCloud sync is off because this device isn't signed in to iCloud. Sign in from the device's Settings to \
            sync.
            """,
        bundle: .main, comment: "plain. iCloud status.")

    static let cloudRestricted = LocalizedStringResource(
        "plain.settings.icloud.restricted",
        defaultValue: """
            iCloud sync is off because iCloud isn't allowed on this device. Screen Time or a work or school profile \
            can block it.
            """,
        bundle: .main, comment: "plain. iCloud status.")

    static let cloudTemporarilyUnavailable = LocalizedStringResource(
        "plain.settings.icloud.temporarilyUnavailable",
        defaultValue: "iCloud is signed in but isn't ready yet. Sync starts again on its own.",
        bundle: .main, comment: "plain. iCloud status.")

    static let cloudUnknown = LocalizedStringResource(
        "plain.settings.icloud.unknown",
        defaultValue: "Couldn't check iCloud just now. Your data is safe on this device.",
        bundle: .main, comment: "plain. iCloud status.")

    static let cloudChecking = LocalizedStringResource(
        "plain.settings.icloud.checking",
        defaultValue: "Checking iCloud…",
        bundle: .main, comment: "plain. iCloud status while it's being read.")
}
