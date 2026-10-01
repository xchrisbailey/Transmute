// swiftlint:disable file_length
import Foundation

/// Strings for onboarding and the Profile screen (#6). Voice for the welcome and hand-off;
/// plain everywhere else, and always for Health and limitations (#3).
public enum ProfileCopy {
    static let welcome = LocalizedStringResource(
        "voice.onboarding.welcome",
        defaultValue: "Tell Transmute about you and your goals, and it'll brew a training plan that fits.",
        bundle: .main,
        comment: "voice. Onboarding welcome line under the mark.")

    static let getStarted = LocalizedStringResource(
        "plain.getStarted", defaultValue: "Get started", bundle: .main,
        comment: "plain. Onboarding welcome button.")

    static let healthPrefill = LocalizedStringResource(
        "plain.onboarding.healthPrefill",
        defaultValue: "Transmute can fill in your height, weight, birth year and sex from Health. You can skip this.",
        bundle: .main,
        comment: "plain. Offer to prefill from Health.")

    static let useHealth = LocalizedStringResource(
        "plain.useHealth", defaultValue: "Fill in from Health", bundle: .main,
        comment: "plain. Button that asks for Health access and prefills.")

    static let healthFilled = LocalizedStringResource(
        "plain.healthFilled", defaultValue: "Filled in from Health. Check it over.", bundle: .main,
        comment: "plain. After a Health prefill.")

    static let healthEmpty = LocalizedStringResource(
        "plain.healthEmpty", defaultValue: "Health didn't have anything to fill in. Enter it below.", bundle: .main,
        comment: "plain. Health prefill found nothing, or access was denied.")

    static let continueButton = LocalizedStringResource(
        "plain.continue", defaultValue: "Continue", bundle: .main,
        comment: "plain. Onboarding next button.")

    static let back = LocalizedStringResource(
        "plain.back", defaultValue: "Back", bundle: .main,
        comment: "plain. Onboarding back button.")

    static let skip = LocalizedStringResource(
        "plain.skip", defaultValue: "Skip", bundle: .main,
        comment: "plain. Skip an optional onboarding step.")

    static func step(_ step: Int, _ total: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "plain.onboarding.step", defaultValue: "Step \(step) of \(total)", bundle: .main,
            comment: "plain. Onboarding progress for VoiceOver.")
    }

    static let bodyTitle = LocalizedStringResource(
        "plain.onboarding.bodyTitle", defaultValue: "About you", bundle: .main,
        comment: "plain. Onboarding body step title.")

    static let bodyNote = LocalizedStringResource(
        "plain.onboarding.bodyNote",
        defaultValue: "Height and weight help set safe starting loads. Everything else is optional.", bundle: .main,
        comment: "plain. Onboarding body step.")

    static let height = LocalizedStringResource(
        "plain.height", defaultValue: "Height", bundle: .main,
        comment: "plain. Field label.")

    static let weight = LocalizedStringResource(
        "plain.weight", defaultValue: "Weight", bundle: .main,
        comment: "plain. Field label.")

    static let birthYear = LocalizedStringResource(
        "plain.birthYear", defaultValue: "Birth year", bundle: .main,
        comment: "plain. Field label.")

    static let sex = LocalizedStringResource(
        "plain.sex", defaultValue: "Sex", bundle: .main,
        comment: "plain. Field label.")

    static let sexNote = LocalizedStringResource(
        "plain.sexNote", defaultValue: "Optional. Only used for estimates.", bundle: .main,
        comment: "plain. Under the sex picker.")

    static let preferNotToSay = LocalizedStringResource(
        "plain.preferNotToSay", defaultValue: "Prefer not to say", bundle: .main,
        comment: "plain. Sex picker option.")

    static let female = LocalizedStringResource(
        "plain.sex.female", defaultValue: "Female", bundle: .main,
        comment: "plain. Sex picker option.")

    static let male = LocalizedStringResource(
        "plain.sex.male", defaultValue: "Male", bundle: .main,
        comment: "plain. Sex picker option.")

    static let otherSex = LocalizedStringResource(
        "plain.sex.other", defaultValue: "Other", bundle: .main,
        comment: "plain. Sex picker option.")

    static let units = LocalizedStringResource(
        "plain.units", defaultValue: "Units", bundle: .main,
        comment: "plain. Unit system picker.")

    static let imperial = LocalizedStringResource(
        "plain.units.imperial", defaultValue: "lb and ft", bundle: .main,
        comment: "plain. Unit system option.")

    static let metric = LocalizedStringResource(
        "plain.units.metric", defaultValue: "kg and cm", bundle: .main,
        comment: "plain. Unit system option.")

    static let feet = LocalizedStringResource(
        "plain.feet", defaultValue: "Feet", bundle: .main,
        comment: "plain. Height field, accessibility label.")

    static let inches = LocalizedStringResource(
        "plain.inches", defaultValue: "Inches", bundle: .main,
        comment: "plain. Height field, accessibility label.")

    static let checkHeight = LocalizedStringResource(
        "plain.issue.height", defaultValue: "Enter a height between 4 ft and 7 ft 6 in (120 to 230 cm).", bundle: .main,
        comment: "plain. Validation.")

    static let checkWeight = LocalizedStringResource(
        "plain.issue.weight", defaultValue: "Enter a weight between 66 and 660 lb (30 to 300 kg).", bundle: .main,
        comment: "plain. Validation.")

    static let checkBirthYear = LocalizedStringResource(
        "plain.issue.birthYear", defaultValue: "Check the birth year. Transmute is for ages 13 and up.", bundle: .main,
        comment: "plain. Validation.")
}

// Experience, goals, sport and schedule.
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

// Equipment, limitations, the hand-off and the Profile screen.
extension ProfileCopy {
    static let equipmentTitle = LocalizedStringResource(
        "plain.onboarding.equipmentTitle", defaultValue: "What can you train with?", bundle: .main,
        comment: "plain. Onboarding equipment step title.")

    static let fullGym = LocalizedStringResource(
        "plain.preset.fullGym", defaultValue: "Full gym", bundle: .main,
        comment: "plain. Equipment preset.")

    static let homeDumbbells = LocalizedStringResource(
        "plain.preset.homeDumbbells", defaultValue: "Home dumbbells", bundle: .main,
        comment: "plain. Equipment preset.")

    static let bodyweightOnly = LocalizedStringResource(
        "plain.preset.bodyweightOnly", defaultValue: "Bodyweight only", bundle: .main,
        comment: "plain. Equipment preset.")

    static let everything = LocalizedStringResource(
        "plain.equipment.everything", defaultValue: "Everything", bundle: .main,
        comment: "plain. Disclosure listing every piece of equipment.")

    static let barbellWeight = LocalizedStringResource(
        "plain.barbellWeight", defaultValue: "Barbell weight", bundle: .main,
        comment: "plain. Field label, for the plate calculator.")

    static let limitationsTitle = LocalizedStringResource(
        "plain.onboarding.limitationsTitle", defaultValue: "Injuries or limits", bundle: .main,
        comment: "plain. Onboarding limitations step title.")

    static let limitationsPrompt = LocalizedStringResource(
        "plain.onboarding.limitationsPrompt", defaultValue: "e.g. sore left knee, no overhead pressing", bundle: .main,
        comment: "plain. Limitations field placeholder.")

    static let limitationsNote = LocalizedStringResource(
        "plain.onboarding.limitationsNote",
        defaultValue:
            "Plans leave out anything that loads these. Transmute isn't medical advice, so check with a professional about injuries.",
        bundle: .main,
        comment: "plain. Under limitations.")

    static let areas = LocalizedStringResource(
        "plain.onboarding.areas", defaultValue: "Areas to go easy on", bundle: .main,
        comment: "plain. Above body area chips.")

    static let readyTitle = LocalizedStringResource(
        "voice.onboarding.readyTitle", defaultValue: "Ready to brew", bundle: .main,
        comment: "voice. Onboarding hand-off title.")

    static let readyBody = LocalizedStringResource(
        "voice.onboarding.readyBody",
        defaultValue:
            "Transmute has what it needs. Brew your first plan now; you can change any of this later in Profile.",
        bundle: .main,
        comment: "voice. Onboarding hand-off.")

    static let later = LocalizedStringResource(
        "plain.later", defaultValue: "Later", bundle: .main,
        comment: "plain. Finish onboarding without brewing.")

    public static let profile = LocalizedStringResource(
        "plain.profile", defaultValue: "Profile", bundle: .main,
        comment: "plain. Screen title.")

    public static let save = LocalizedStringResource(
        "plain.save", defaultValue: "Save", bundle: .main,
        comment: "plain. Button.")

    public static let cancel = LocalizedStringResource(
        "plain.cancel", defaultValue: "Cancel", bundle: .main,
        comment: "plain. Button.")

    static let goal = LocalizedStringResource(
        "plain.goal", defaultValue: "Goal", bundle: .main,
        comment: "plain. Profile section.")

    static let experience = LocalizedStringResource(
        "plain.experience", defaultValue: "Experience", bundle: .main,
        comment: "plain. Profile section.")

    static let schedule = LocalizedStringResource(
        "plain.schedule", defaultValue: "Schedule", bundle: .main,
        comment: "plain. Profile section.")

    static let bodyweight = LocalizedStringResource(
        "plain.bodyweight", defaultValue: "Bodyweight", bundle: .main,
        comment: "plain. Profile bodyweight history section.")

    static let addWeight = LocalizedStringResource(
        "plain.addWeight", defaultValue: "Add weight", bundle: .main,
        comment: "plain. Button.")

    static let importFromHealth = LocalizedStringResource(
        "plain.importFromHealth", defaultValue: "Import from Health", bundle: .main,
        comment: "plain. Button.")

    static let fromHealth = LocalizedStringResource(
        "plain.fromHealth", defaultValue: "From Health", bundle: .main,
        comment: "plain. Badge on a bodyweight that came from Health.")

    static let noWeights = LocalizedStringResource(
        "plain.noWeights", defaultValue: "No weights yet.", bundle: .main,
        comment: "plain. Empty bodyweight history.")

    static let date = LocalizedStringResource(
        "plain.date", defaultValue: "Date", bundle: .main,
        comment: "plain. Field label.")

    static let deleteWeight = LocalizedStringResource(
        "plain.deleteWeight", defaultValue: "Delete", bundle: .main,
        comment: "plain. Swipe action on a bodyweight entry.")

    static let neck = LocalizedStringResource(
        "plain.bodyArea.neck", defaultValue: "Neck", bundle: .main,
        comment: "plain. Body area chip.")

    static let shoulder = LocalizedStringResource(
        "plain.bodyArea.shoulder", defaultValue: "Shoulders", bundle: .main,
        comment: "plain. Body area chip.")

    static let elbow = LocalizedStringResource(
        "plain.bodyArea.elbow", defaultValue: "Elbows", bundle: .main,
        comment: "plain. Body area chip.")

    static let wrist = LocalizedStringResource(
        "plain.bodyArea.wrist", defaultValue: "Wrists", bundle: .main,
        comment: "plain. Body area chip.")

    static let upperBack = LocalizedStringResource(
        "plain.bodyArea.upperBack", defaultValue: "Upper back", bundle: .main,
        comment: "plain. Body area chip.")

    static let lowerBack = LocalizedStringResource(
        "plain.bodyArea.lowerBack", defaultValue: "Lower back", bundle: .main,
        comment: "plain. Body area chip.")

    static let hip = LocalizedStringResource(
        "plain.bodyArea.hip", defaultValue: "Hips", bundle: .main,
        comment: "plain. Body area chip.")

    static let knee = LocalizedStringResource(
        "plain.bodyArea.knee", defaultValue: "Knees", bundle: .main,
        comment: "plain. Body area chip.")

    static let ankle = LocalizedStringResource(
        "plain.bodyArea.ankle", defaultValue: "Ankles", bundle: .main,
        comment: "plain. Body area chip.")

    static let selected = LocalizedStringResource(
        "plain.selected", defaultValue: "Selected", bundle: .main,
        comment: "plain. Accessibility value for a chosen chip.")
}
// swiftlint:enable file_length
