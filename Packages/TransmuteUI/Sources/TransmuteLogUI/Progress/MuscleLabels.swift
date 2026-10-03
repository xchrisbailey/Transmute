import Foundation
import TransmuteCore

extension Muscle {
    /// The muscle group's plain name, for the volume chart's legend.
    var label: LocalizedStringResource {
        switch self {
        case .quads:
            LocalizedStringResource(
                "plain.muscle.quads", defaultValue: "Quads", bundle: .main, comment: "plain. Muscle group.")
        case .hamstrings:
            LocalizedStringResource(
                "plain.muscle.hamstrings", defaultValue: "Hamstrings", bundle: .main, comment: "plain. Muscle group.")
        case .glutes:
            LocalizedStringResource(
                "plain.muscle.glutes", defaultValue: "Glutes", bundle: .main, comment: "plain. Muscle group.")
        case .adductors:
            LocalizedStringResource(
                "plain.muscle.adductors", defaultValue: "Adductors", bundle: .main, comment: "plain. Muscle group.")
        case .abductors:
            LocalizedStringResource(
                "plain.muscle.abductors", defaultValue: "Abductors", bundle: .main, comment: "plain. Muscle group.")
        case .calves:
            LocalizedStringResource(
                "plain.muscle.calves", defaultValue: "Calves", bundle: .main, comment: "plain. Muscle group.")
        case .hipFlexors:
            LocalizedStringResource(
                "plain.muscle.hipFlexors", defaultValue: "Hip flexors", bundle: .main, comment: "plain. Muscle group.")
        case .chest:
            LocalizedStringResource(
                "plain.muscle.chest", defaultValue: "Chest", bundle: .main, comment: "plain. Muscle group.")
        case .frontDelts:
            LocalizedStringResource(
                "plain.muscle.frontDelts", defaultValue: "Front delts", bundle: .main, comment: "plain. Muscle group.")
        case .sideDelts:
            LocalizedStringResource(
                "plain.muscle.sideDelts", defaultValue: "Side delts", bundle: .main, comment: "plain. Muscle group.")
        case .rearDelts:
            LocalizedStringResource(
                "plain.muscle.rearDelts", defaultValue: "Rear delts", bundle: .main, comment: "plain. Muscle group.")
        case .triceps:
            LocalizedStringResource(
                "plain.muscle.triceps", defaultValue: "Triceps", bundle: .main, comment: "plain. Muscle group.")
        case .biceps:
            LocalizedStringResource(
                "plain.muscle.biceps", defaultValue: "Biceps", bundle: .main, comment: "plain. Muscle group.")
        case .forearms:
            LocalizedStringResource(
                "plain.muscle.forearms", defaultValue: "Forearms", bundle: .main, comment: "plain. Muscle group.")
        case .lats:
            LocalizedStringResource(
                "plain.muscle.lats", defaultValue: "Lats", bundle: .main, comment: "plain. Muscle group.")
        case .upperBack:
            LocalizedStringResource(
                "plain.muscle.upperBack", defaultValue: "Upper back", bundle: .main, comment: "plain. Muscle group.")
        case .traps:
            LocalizedStringResource(
                "plain.muscle.traps", defaultValue: "Traps", bundle: .main, comment: "plain. Muscle group.")
        case .lowerBack:
            LocalizedStringResource(
                "plain.muscle.lowerBack", defaultValue: "Lower back", bundle: .main, comment: "plain. Muscle group.")
        case .abs:
            LocalizedStringResource(
                "plain.muscle.abs", defaultValue: "Abs", bundle: .main, comment: "plain. Muscle group.")
        case .obliques:
            LocalizedStringResource(
                "plain.muscle.obliques", defaultValue: "Obliques", bundle: .main, comment: "plain. Muscle group.")
        case .rotatorCuff:
            LocalizedStringResource(
                "plain.muscle.rotatorCuff", defaultValue: "Rotator cuff", bundle: .main, comment: "plain. Muscle group."
            )
        case .neck:
            LocalizedStringResource(
                "plain.muscle.neck", defaultValue: "Neck", bundle: .main, comment: "plain. Muscle group.")
        case .fullBody:
            LocalizedStringResource(
                "plain.muscle.fullBody", defaultValue: "Full body", bundle: .main, comment: "plain. Muscle group.")
        case .cardio:
            LocalizedStringResource(
                "plain.muscle.cardio", defaultValue: "Cardio", bundle: .main, comment: "plain. Muscle group.")
        }
    }
}
