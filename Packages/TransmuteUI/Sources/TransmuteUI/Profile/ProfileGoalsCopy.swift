import Foundation

extension ProfileCopy {
    static let experienceTitle = LocalizedStringResource(
        "plain.onboarding.experienceTitle", defaultValue: "How much have you trained?", bundle: .main,
        comment: "plain. Onboarding experience step title.")

    static let beginner = LocalizedStringResource(
        "plain.experience.beginner", defaultValue: "New", bundle: .main,
        comment: "plain. Experience level.")

    static let beginnerDetail = LocalizedStringResource(
        "plain.experience.beginnerDetail", defaultValue: "I've never lifted weights, or not for a long time.",
        bundle: .main,
        comment: "plain. Experience level description.")

    static let intermediate = LocalizedStringResource(
        "plain.experience.intermediate", defaultValue: "Some", bundle: .main,
        comment: "plain. Experience level.")

    static let intermediateDetail = LocalizedStringResource(
        "plain.experience.intermediateDetail", defaultValue: "I train on and off.", bundle: .main,
        comment: "plain. Experience level description.")

    static let advanced = LocalizedStringResource(
        "plain.experience.advanced", defaultValue: "Experienced", bundle: .main,
        comment: "plain. Experience level.")

    static let advancedDetail = LocalizedStringResource(
        "plain.experience.advancedDetail", defaultValue: "I train regularly and know my numbers.", bundle: .main,
        comment: "plain. Experience level description.")

    static let knownLiftsTitle = LocalizedStringResource(
        "plain.onboarding.knownLifts", defaultValue: "Your numbers", bundle: .main,
        comment: "plain. Section for known lifts, experienced only.")

    static let knownLiftsNote = LocalizedStringResource(
        "plain.onboarding.knownLiftsNote",
        defaultValue: "Optional. A recent hard set of any of these helps set starting weights.", bundle: .main,
        comment: "plain. Under known lifts.")

    static let reps = LocalizedStringResource(
        "plain.reps", defaultValue: "Reps", bundle: .main,
        comment: "plain. Field label.")

    static let goalsTitle = LocalizedStringResource(
        "plain.onboarding.goalsTitle", defaultValue: "What do you want from training?", bundle: .main,
        comment: "plain. Onboarding goals step title.")

    static let goalPrompt = LocalizedStringResource(
        "plain.onboarding.goalPrompt", defaultValue: "In your own words, e.g. lose 20 lb before summer", bundle: .main,
        comment: "plain. Goal text field placeholder.")

    static let goalChips = LocalizedStringResource(
        "plain.onboarding.goalChips", defaultValue: "Pick any that fit", bundle: .main,
        comment: "plain. Above the goal chips.")

    static let goalWeightLoss = LocalizedStringResource(
        "plain.goal.weightLoss", defaultValue: "Lose weight", bundle: .main,
        comment: "plain. Goal chip.")

    static let goalStrength = LocalizedStringResource(
        "plain.goal.strength", defaultValue: "Get stronger", bundle: .main,
        comment: "plain. Goal chip.")

    static let goalMuscle = LocalizedStringResource(
        "plain.goal.hypertrophy", defaultValue: "Build muscle", bundle: .main,
        comment: "plain. Goal chip.")

    static let goalEndurance = LocalizedStringResource(
        "plain.goal.endurance", defaultValue: "Fitness and endurance", bundle: .main,
        comment: "plain. Goal chip.")

    static let goalMobility = LocalizedStringResource(
        "plain.goal.mobility", defaultValue: "Mobility", bundle: .main,
        comment: "plain. Goal chip.")

    static let goalSport = LocalizedStringResource(
        "plain.goal.sportPerformance", defaultValue: "Sport performance", bundle: .main,
        comment: "plain. Goal chip.")

    static let sportTitle = LocalizedStringResource(
        "plain.onboarding.sportTitle", defaultValue: "Your sport", bundle: .main,
        comment: "plain. Onboarding sport step title.")

    static let sportPrompt = LocalizedStringResource(
        "plain.onboarding.sportPrompt", defaultValue: "e.g. tennis, 4.0 NTRP, plays 3× a week", bundle: .main,
        comment: "plain. Sport field placeholder.")

    static let sportNote = LocalizedStringResource(
        "plain.onboarding.sportNote",
        defaultValue: "Optional. Plans work around it, but the sport itself isn't logged in Transmute.", bundle: .main,
        comment: "plain. Under the sport field.")

    static let scheduleTitle = LocalizedStringResource(
        "plain.onboarding.scheduleTitle", defaultValue: "Your week", bundle: .main,
        comment: "plain. Onboarding schedule step title.")

    static func daysPerWeek(_ days: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.daysPerWeek", defaultValue: "Days a week: \(days)", bundle: .main,
            comment: "plain. Stepper.")
    }

    static let whichDays = LocalizedStringResource(
        "plain.whichDays", defaultValue: "Which days", bundle: .main,
        comment: "plain. Weekday picker title.")

    static func pickDays(_ days: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.issue.pickDays", defaultValue: "Pick \(days) days, or clear them and Transmute will choose.",
            bundle: .main,
            comment: "plain. Validation.")
    }

    static func sessionLength(_ minutes: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.sessionLength", defaultValue: "Session length: \(minutes) min", bundle: .main,
            comment: "plain. Stepper.")
    }

    static func planLength(_ weeks: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.planLength", defaultValue: "Plan length: \(weeks) weeks", bundle: .main,
            comment: "plain. Stepper.")
    }

    static let commitments = LocalizedStringResource(
        "plain.commitments", defaultValue: "Matches and practice", bundle: .main,
        comment: "plain. Fixed commitments section.")

    static let commitmentsNote = LocalizedStringResource(
        "plain.commitmentsNote", defaultValue: "Hard sessions stay off these days.", bundle: .main,
        comment: "plain. Under fixed commitments.")

    static let addCommitment = LocalizedStringResource(
        "plain.addCommitment", defaultValue: "Add a day", bundle: .main,
        comment: "plain. Button.")

    static let commitmentLabel = LocalizedStringResource(
        "plain.commitmentLabel", defaultValue: "What", bundle: .main,
        comment: "plain. Commitment name field, e.g. Match.")

    static let defaultCommitment = LocalizedStringResource(
        "plain.defaultCommitment", defaultValue: "Match", bundle: .main,
        comment: "plain. Default commitment name.")

    static let day = LocalizedStringResource(
        "plain.day", defaultValue: "Day", bundle: .main,
        comment: "plain. Weekday picker.")

    static let intensity = LocalizedStringResource(
        "plain.intensity", defaultValue: "How hard", bundle: .main,
        comment: "plain. Commitment intensity picker.")

    static let light = LocalizedStringResource(
        "plain.intensity.light", defaultValue: "Light", bundle: .main,
        comment: "plain. Intensity.")

    static let moderate = LocalizedStringResource(
        "plain.intensity.moderate", defaultValue: "Moderate", bundle: .main,
        comment: "plain. Intensity.")

    static let hard = LocalizedStringResource(
        "plain.intensity.hard", defaultValue: "Hard", bundle: .main,
        comment: "plain. Intensity.")
}
