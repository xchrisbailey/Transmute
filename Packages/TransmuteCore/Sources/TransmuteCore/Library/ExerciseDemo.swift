import Foundation

/// Bundled editorial content, never a workout attribute or an equipment-used record.
public struct ExerciseDemo: Codable, Hashable, Sendable {
    public enum Captions: String, Codable, Sendable {
        case notNeeded
        case reviewed
    }

    public var exerciseID: String
    public var equipment: Set<Equipment>
    public var videoID: String
    public var reviewedBy: String
    public var reviewedOn: String
    public var movementReview: String
    public var mutedReview: String
    public var captions: Captions
    public var captionReview: String?

    public init(
        exerciseID: String, equipment: Set<Equipment>, videoID: String,
        reviewedBy: String, reviewedOn: String, movementReview: String, mutedReview: String,
        captions: Captions, captionReview: String?
    ) {
        self.exerciseID = exerciseID
        self.equipment = equipment
        self.videoID = videoID
        self.reviewedBy = reviewedBy
        self.reviewedOn = reviewedOn
        self.movementReview = movementReview
        self.mutedReview = mutedReview
        self.captions = captions
        self.captionReview = captionReview
    }

    func isValid(for exercise: LibraryExercise) -> Bool {
        // Fail closed: metadata cannot prove footage quality, but incomplete or mismatched
        // records must never turn a candidate into user-visible guidance.
        guard !exercise.isCustom, exercise.id == exerciseID,
            !exercise.equipment.isEmpty, !exercise.cues.isEmpty,
            equipment.isSubset(of: exercise.allEquipment),
            exercise.equipment.allSatisfy({ equipment.intersection($0).count == 1 }),
            videoID.utf8.count == 11,
            videoID.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95
            }),
            [reviewedBy, movementReview, mutedReview].allSatisfy({
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }),
            reviewedOn.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        else { return false }
        return captions == .notNeeded
            || !(captionReview?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

/// One equipment variant a person can view, with its reviewed demonstration when there is one.
public struct DemoChoice: Hashable, Sendable {
    public let equipment: Set<Equipment>
    public let demo: ExerciseDemo?
}
