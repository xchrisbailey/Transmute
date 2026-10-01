import Foundation
import Testing
@testable import TransmuteCore

struct ExerciseLibraryTests {
    let library = ExerciseLibrary.bundled

    // MARK: Catalog integrity

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

    // MARK: Tennis coverage, from the "done when" in #5

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

    // MARK: Search

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

    // MARK: Custom exercises

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
