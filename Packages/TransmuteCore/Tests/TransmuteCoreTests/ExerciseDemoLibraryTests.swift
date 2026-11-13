import Foundation
import Testing

@testable import TransmuteCore

struct ExerciseDemoLibraryTests {
    let library = ExerciseLibrary.bundled

    @Test func demosRequireAnExactReviewedLibraryAssociation() throws {
        let pushUp = try #require(library.exercise(id: "push-up"))
        let fixture = ExerciseDemo(
            exerciseID: "push-up", equipment: [.bodyweight], videoID: "TESTONLY001",
            reviewedBy: "Test fixture, not content approval", reviewedOn: "2026-11-04",
            movementReview: "Test-only movement review", mutedReview: "Test-only muted review",
            captions: .notNeeded, captionReview: nil)
        let reviewed = ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [fixture])
        #expect(reviewed.demo(exerciseID: "push-up", equipment: [.bodyweight]) == fixture)
        #expect(reviewed.demo(exerciseID: "push-up", equipment: [.dumbbell]) == nil)
        #expect(reviewed.demo(exerciseID: "custom-push-up", equipment: [.bodyweight]) == nil)
        #expect(reviewed.demo(exerciseID: "back-squat", equipment: [.barbell, .rack]) == nil)
        var renamed = pushUp
        renamed.name = "Floor push-up"
        #expect(
            ExerciseLibrary(catalogVersion: 1, exercises: [renamed], demos: [fixture])
                .demo(exerciseID: "push-up", equipment: [.bodyweight]) == fixture)
        #expect(
            ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [fixture, fixture])
                .demo(exerciseID: "push-up", equipment: [.bodyweight]) == nil)
        var invalid = fixture
        invalid.equipment = [.dumbbell]
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [invalid]).demos.isEmpty)
        invalid = fixture
        invalid.captions = .reviewed
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [invalid]).demos.isEmpty)
        invalid = fixture
        invalid.videoID = "../bad?video"
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [pushUp], demos: [invalid]).demos.isEmpty)
    }

    private func key(_ demo: ExerciseDemo) -> String {
        "\(demo.exerciseID)/\(demo.equipment.map(\.rawValue).sorted().joined(separator: "+"))"
    }

    @Test func bundledDemosAreExactlyTheHumanApprovedSet() throws {
        let keys = library.demos.map(key)
        #expect(
            keys.sorted() == [
                "goblet-squat/dumbbell", "goblet-squat/kettlebell", "push-up/bodyweight",
                "romanian-deadlift/barbell",
            ])
        let videos: [String: String] = [
            "push-up/bodyweight": "WDIpL0pjun0", "goblet-squat/dumbbell": "3O77G_yiFUw",
            "goblet-squat/kettlebell": "MWHIs0zxkCU", "romanian-deadlift/barbell": "Roe2hOnzXf4",
        ]
        for demo in library.demos {
            #expect(demo.videoID == videos[key(demo)], "\(key(demo))")
            #expect(demo.reviewedBy == "Human maintainer xchrisbailey")
            #expect(demo.movementReview.contains("https://github.com/xchrisbailey/Transmute/issues/11"))
            #expect(demo.mutedReview.contains("https://github.com/xchrisbailey/Transmute/issues/11"))
        }
        let pushUp = try #require(library.demo(exerciseID: "push-up", equipment: [.bodyweight]))
        #expect(pushUp.reviewedOn == "2026-11-05" && pushUp.captions == .notNeeded && pushUp.captionReview == nil)
        #expect(pushUp.movementReview.contains("issues/118#issuecomment-6650523285"))
        #expect(pushUp.mutedReview.contains("issues/118#issuecomment-6650533058"))
        let added: [(String, Equipment)] = [
            ("goblet-squat", .dumbbell), ("goblet-squat", .kettlebell), ("romanian-deadlift", .barbell),
        ]
        for (id, equipment) in added {
            let demo = try #require(library.demo(exerciseID: id, equipment: [equipment]))
            #expect(demo.reviewedOn == "2026-11-13" && demo.captions == .reviewed)
            #expect(demo.movementReview.contains("issues/119#issuecomment-6844696504"))
            #expect(demo.captionReview?.contains("issues/119#issuecomment-6844696504") == true)
        }
        // Multi-equipment choice, and a missing match that never borrows another variant's video.
        #expect(library.demoChoices(exerciseID: "goblet-squat").map(\.equipment) == [[.dumbbell], [.kettlebell]])
        #expect(library.demoChoices(exerciseID: "goblet-squat").allSatisfy { $0.demo != nil })
        let rdl = library.demoChoices(exerciseID: "romanian-deadlift")
        #expect(rdl.map(\.equipment) == [[.barbell], [.dumbbell]])
        #expect(rdl.map { $0.demo?.videoID } == ["Roe2hOnzXf4", nil])
        #expect(library.demo(exerciseID: "romanian-deadlift", equipment: [.dumbbell]) == nil)
        for id in ["incline-push-up", "deficit-push-up", "dumbbell-romanian-deadlift", "custom-push-up"] {
            #expect(library.demoChoices(exerciseID: id).isEmpty, "\(id)")
        }
    }

    private func synthetic(_ id: String, _ equipment: Set<Equipment>, video: String) -> ExerciseDemo {
        ExerciseDemo(
            exerciseID: id, equipment: equipment, videoID: video,
            reviewedBy: "Test fixture, not content approval", reviewedOn: "2026-11-12",
            movementReview: "Test-only movement review", mutedReview: "Test-only muted review",
            captions: .notNeeded, captionReview: nil)
    }

    @Test func equipmentChoicesFollowTheCatalogueGroupsAndNeverFallBackToAnotherVariant() throws {
        let goblet = try #require(library.exercise(id: "goblet-squat"))
        let press = try #require(library.exercise(id: "dumbbell-bench-press"))
        let dumbbell = synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001")
        let kettlebell = synthetic("goblet-squat", [.kettlebell], video: "TESTONLY002")
        let bench = synthetic("dumbbell-bench-press", [.dumbbell, .bench], video: "TESTONLY003")
        let reviewed = ExerciseLibrary(
            catalogVersion: 1, exercises: [goblet, press], demos: [dumbbell, kettlebell, bench])
        #expect(reviewed.demos.count == 3)
        #expect(reviewed.demoChoices(exerciseID: "goblet-squat").map(\.equipment) == [[.dumbbell], [.kettlebell]])
        #expect(reviewed.demoChoices(exerciseID: "goblet-squat").map(\.demo) == [dumbbell, kettlebell])
        #expect(reviewed.demo(exerciseID: "goblet-squat", equipment: [.dumbbell]) == dumbbell)
        #expect(reviewed.demo(exerciseID: "goblet-squat", equipment: [.kettlebell]) == kettlebell)
        // A group is alternatives; an AND group is one required item, never a choice.
        #expect(reviewed.demoChoices(exerciseID: "dumbbell-bench-press").map(\.equipment) == [[.dumbbell, .bench]])
        #expect(reviewed.demo(exerciseID: "dumbbell-bench-press", equipment: [.dumbbell]) == nil)
        #expect(reviewed.demo(exerciseID: "dumbbell-bench-press", equipment: [.bench]) == nil)

        // Only one alternative reviewed: the other stays a visible choice without a demo.
        let partial = ExerciseLibrary(catalogVersion: 1, exercises: [goblet], demos: [dumbbell])
        let choices = partial.demoChoices(exerciseID: "goblet-squat")
        #expect(choices.map(\.equipment) == [[.dumbbell], [.kettlebell]])
        #expect(choices.map(\.demo) == [dumbbell, nil])
        #expect(partial.demo(exerciseID: "goblet-squat", equipment: [.kettlebell]) == nil)
        #expect(partial.demo(exerciseID: "goblet-squat", equipment: [.barbell]) == nil)

        // No reviewed demo for any variant: no choices, no guessed guidance.
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [goblet]).demoChoices(exerciseID: "goblet-squat").isEmpty)
    }

    /// A bundled catalog as the file stores it, so a shipped correction is exactly an edited record.
    private func shipped(_ records: [(equipment: String, video: String)]) throws -> ExerciseLibrary {
        let json = records.map {
            """
            {"exerciseID": "goblet-squat", "equipment": ["\($0.equipment)"], "videoID": "\($0.video)",
             "reviewedBy": "Test fixture, not content approval", "reviewedOn": "2026-11-12",
             "movementReview": "Test-only movement review", "mutedReview": "Test-only muted review",
             "captions": "notNeeded", "captionReview": null}
            """
        }.joined(separator: ",")
        let demos = try JSONDecoder().decode([ExerciseDemo].self, from: Data("[\(json)]".utf8))
        let goblet = try #require(library.exercise(id: "goblet-squat"))
        return ExerciseLibrary(catalogVersion: 1, exercises: [goblet], demos: demos)
    }

    @Test func anAppUpdateReplacesOrRemovesOneAssociationWithoutTouchingTheExercise() throws {
        let installed = try shipped([("dumbbell", "TESTONLY001"), ("kettlebell", "TESTONLY002")])
        let replaced = try shipped([("dumbbell", "TESTONLY001"), ("kettlebell", "TESTONLY003")])
        let removed = try shipped([("dumbbell", "TESTONLY001")])
        let id = "goblet-squat"
        for update in [installed, replaced, removed] {
            #expect(update.exercise(id: id)?.id == id, "The stable ID never changes")
            #expect(update.demo(exerciseID: id, equipment: [.dumbbell])?.videoID == "TESTONLY001")
        }
        #expect(installed.demo(exerciseID: id, equipment: [.kettlebell])?.videoID == "TESTONLY002")
        #expect(replaced.demo(exerciseID: id, equipment: [.kettlebell])?.videoID == "TESTONLY003")
        #expect(removed.demo(exerciseID: id, equipment: [.kettlebell]) == nil)
        #expect(removed.demoChoices(exerciseID: id).map { $0.demo?.videoID } == ["TESTONLY001", nil])
        #expect(try shipped([]).demoChoices(exerciseID: id).isEmpty, "Removing the last one leaves written cues")
        // The shipped content itself is untouched by any of this.
        #expect(ExerciseLibrary.bundled.demos.count == 4)
    }

    @Test func ambiguousOrMismatchedAssociationsAreRejected() throws {
        let goblet = try #require(library.exercise(id: "goblet-squat"))
        let press = try #require(library.exercise(id: "dumbbell-bench-press"))
        let dumbbell = synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001")
        var otherVideo = dumbbell
        otherVideo.videoID = "TESTONLY002"
        // Two videos for one exercise and equipment key are ambiguous: neither is shown.
        let ambiguous = ExerciseLibrary(catalogVersion: 1, exercises: [goblet], demos: [dumbbell, otherVideo])
        #expect(ambiguous.demos.isEmpty && ambiguous.demoChoices(exerciseID: "goblet-squat").isEmpty)
        // Both alternatives at once is not a single implement.
        let both = synthetic("goblet-squat", [.dumbbell, .kettlebell], video: "TESTONLY001")
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [goblet], demos: [both]).demos.isEmpty)
        // An AND group must be named in the demonstrated equipment.
        let noBench = synthetic("dumbbell-bench-press", [.dumbbell], video: "TESTONLY001")
        #expect(ExerciseLibrary(catalogVersion: 1, exercises: [press], demos: [noBench]).demos.isEmpty)
        // A demo cannot be attached to a custom exercise even when the ID is known.
        let custom = LibraryExercise(
            id: "custom-goblet", name: "Goblet squat", category: .strength, pattern: .squat,
            primaryMuscles: [.quads], equipment: [[.dumbbell]], tracking: .weightReps, cues: ["Hold it close."])
        let attached = synthetic("custom-goblet", [.dumbbell], video: "TESTONLY001")
        let withCustom = ExerciseLibrary(catalogVersion: 1, exercises: [custom], demos: [attached])
        #expect(withCustom.demos.isEmpty && withCustom.demoChoices(exerciseID: "custom-goblet").isEmpty)
    }
}
