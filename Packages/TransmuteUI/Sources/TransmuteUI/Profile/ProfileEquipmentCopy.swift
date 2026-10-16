import Foundation

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
