import Foundation
import Testing

@testable import TransmuteCore

struct ExerciseLibraryTests {
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

    @Test func catalogSizeIsInRange() {
        #expect((250...400).contains(library.exercises.count))
        #expect(library.catalogVersion == 1)
    }

    @Test func idsAreUniqueAndSlugged() {
        let ids = library.exercises.map(\.id)
        #expect(Set(ids).count == ids.count)
        for id in ids {
            #expect(id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }, "\(id)")
            #expect(!id.hasPrefix("custom-"))
        }
    }

    @Test func everyEntryIsComplete() {
        for exercise in library.exercises {
            #expect(!exercise.name.isEmpty, "\(exercise.id)")
            #expect(!exercise.primaryMuscles.isEmpty, "\(exercise.id) has no primary muscle")
            #expect(!exercise.equipment.isEmpty && exercise.equipment.allSatisfy { !$0.isEmpty }, "\(exercise.id)")
            #expect(exercise.cues.count >= 2, "\(exercise.id) needs setup and movement cues")
            #expect(!exercise.mistakes.isEmpty, "\(exercise.id) needs a common mistake")
            #expect(!exercise.sports.isEmpty, "\(exercise.id) has no sport tag")
        }
    }

    @Test func alternativesPointAtRealExercises() {
        for exercise in library.exercises {
            for alternative in [exercise.easier, exercise.harder].compactMap(\.self) {
                #expect(library.exercise(id: alternative) != nil, "\(exercise.id) → \(alternative)")
                #expect(alternative != exercise.id)
            }
        }
    }

    @Test func sampleDataOnlyUsesLibraryExercises() {
        for id in SampleData.exerciseIDs {
            #expect(library.exercise(id: id) != nil, "\(id)")
        }
    }

    @Test func everyCategoryAndTrackingTypeIsCovered() {
        #expect(Set(library.exercises.map(\.category)) == Set(ExerciseCategory.allCases))
        #expect(Set(library.exercises.map(\.tracking)) == Set(TrackingType.allCases))
    }

    @Test func tennisFilterCanFillAFourDayPlan() {
        func count(_ category: ExerciseCategory) -> Int {
            library.search(ExerciseQuery(categories: [category], sports: ["tennis"])).count
        }
        #expect(count(.speedAgility) >= 16)
        #expect(count(.power) >= 16)
        #expect(count(.conditioning) >= 10)
        #expect(count(.strength) >= 40)
        #expect(count(.mobility) >= 20)
    }

    @Test func exactNameRanksFirst() {
        #expect(library.search(ExerciseQuery(text: "back squat")).first?.id == "back-squat")
        #expect(library.search(ExerciseQuery(text: "Deadlift")).first?.id == "deadlift")
    }

    @Test func aliasesMatch() {
        #expect(library.search(ExerciseQuery(text: "RDL")).first?.id == "romanian-deadlift")
        #expect(library.search(ExerciseQuery(text: "5-10-5")).first?.id == "pro-agility-shuttle")
        #expect(library.search(ExerciseQuery(text: "hex bar")).first?.id == "trap-bar-deadlift")
    }

    @Test func searchIgnoresCaseAccentsAndApostrophes() {
        #expect(library.search(ExerciseQuery(text: "FARMERS")).first?.id == "farmers-carry")
        #expect(library.search(ExerciseQuery(text: "worlds greatest")).first?.id == "worlds-greatest-stretch")
        #expect(library.search(ExerciseQuery(text: "Pállof")).contains { $0.id == "pallof-press" })
    }

    @Test func termsCanComeInAnyOrder() {
        #expect(library.search(ExerciseQuery(text: "press bench")).contains { $0.id == "bench-press" })
    }

    @Test func nonsenseFindsNothing() {
        #expect(library.search(ExerciseQuery(text: "zzzz")).isEmpty)
    }

    @Test func filtersCombine() {
        let results = library.search(
            ExerciseQuery(patterns: [.hinge], equipment: [.kettlebell], maxDifficulty: .beginner))
        #expect(!results.isEmpty)
        for exercise in results {
            #expect(exercise.pattern == .hinge)
            #expect(exercise.allEquipment.contains(.kettlebell))
            #expect(exercise.difficulty == .beginner)
        }
    }

    @Test func muscleFilterIncludesSecondary() {
        let results = library.search(ExerciseQuery(muscles: [.rotatorCuff]))
        #expect(results.contains { $0.id == "band-external-rotation" })
        #expect(results.contains { $0.id == "face-pull" })
    }

    @Test func availableEquipmentRespectsRequirements() {
        let homeGym: Set<Equipment> = [.dumbbell, .band]
        let results = library.search(ExerciseQuery(availableEquipment: homeGym))
        #expect(results.contains { $0.id == "goblet-squat" })
        #expect(results.contains { $0.id == "push-up" })
        #expect(!results.contains { $0.id == "bench-press" })
        #expect(!results.contains { $0.id == "dumbbell-bench-press" }, "needs a bench")
        let withBench = library.search(ExerciseQuery(availableEquipment: homeGym.union([.bench])))
        #expect(withBench.contains { $0.id == "dumbbell-bench-press" })
    }

    @Test func doableNeedsOneFromEachGroup() {
        let exercise = LibraryExercise(
            id: "x", name: "X", category: .strength, pattern: .squat, primaryMuscles: [.quads],
            equipment: [[.dumbbell, .kettlebell], [.bench]], tracking: .weightReps)
        #expect(exercise.isDoable(with: [.kettlebell, .bench]))
        #expect(!exercise.isDoable(with: [.kettlebell]))
        #expect(!exercise.isDoable(with: [.bench, .barbell]))
    }

    @Test func searchIsFast() {
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for text in ["s", "sq", "squ", "squa", "squat", "bench", "row", "sprint", "lateral", "band"] {
                _ = library.search(ExerciseQuery(text: text, sports: ["tennis"]))
            }
        }
        // Ten keystrokes' worth of searches should feel instant.
        #expect(elapsed < .milliseconds(100))
    }

    @Test func customExercisesJoinTheLibrary() {
        let custom = CustomExercise(name: "Serve shadow swings", category: .power, pattern: .rotation, tracking: .reps)
        custom.sportTags = ["tennis"]
        let merged = library.adding([LibraryExercise(custom)])
        #expect(merged.exercises.count == library.exercises.count + 1)
        let found = merged.search(ExerciseQuery(text: "serve shadow")).first
        #expect(found?.id == custom.exerciseID)
        #expect(found?.isCustom == true)
        #expect(found?.equipment == [[.bodyweight]])
        #expect(merged.search(ExerciseQuery(categories: [.power], sports: ["tennis"])).contains { $0.isCustom })
    }

    @Test func foldNormalisesText() {
        #expect(ExerciseLibrary.fold("Farmer's  Carry") == "farmers carry")
        #expect(ExerciseLibrary.fold("90/90 hip switch") == "90 90 hip switch")
        #expect(ExerciseLibrary.fold("Pállof") == "pallof")
    }
}
