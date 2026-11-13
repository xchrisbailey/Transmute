import Foundation
import TransmuteCore

func synthetic(_ id: String, _ equipment: Set<Equipment>, video: String) -> ExerciseDemo {
    ExerciseDemo(
        exerciseID: id, equipment: equipment, videoID: video,
        reviewedBy: "Test fixture only", reviewedOn: "2026-11-12",
        movementReview: "Fixture", mutedReview: "Fixture", captions: .notNeeded, captionReview: nil)
}
