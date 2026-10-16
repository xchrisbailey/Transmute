import Foundation

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
