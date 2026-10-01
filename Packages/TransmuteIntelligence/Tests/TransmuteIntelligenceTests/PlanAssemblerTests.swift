import Foundation
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct PlanAssemblerTests {
    let library = ExerciseLibrary.bundled

    func assembler(_ brief: TrainingBrief = .tennisPlayer, units: UnitSystem = .metric) -> PlanAssembler {
        PlanAssembler(brief: brief, units: units, library: library)
    }

    func draft(_ ids: [String], reps: Int = 8, effort: String = "hard", superset: Set<Int> = []) -> DayDraft {
        DayDraft(
            why: "Why",
            exercises: ids.enumerated().map { index, id in
                ExerciseDraft(
                    exerciseID: id, sets: 3, reps: reps, seconds: 30, meters: 20, effort: effort, restSeconds: 90,
                    supersetWithPrevious: superset.contains(index), note: " Brace. ")
            })
    }

    // MARK: Phases

    @Test func phasesStretchToThePlanAndEndOnADeload() {
        let phases = assembler().phases(from: [
            .init(name: "Build", weeks: 2, focus: "Base"), .init(name: "Strength", weeks: 2, focus: "Heavy"),
        ])
        #expect(phases.map(\.name) == ["Build", "Strength", "Deload"])
        #expect(phases.map(\.weeks) == [1...3, 4...7, 8...8])
        #expect(phases.last?.isDeload == true)
    }

    @Test func aModelDeloadIsKeptAsTheLastWeek() {
        var brief = TrainingBrief.tennisPlayer
        brief.schedule.weeks = 6
        let phases = assembler(brief).phases(from: [
            .init(name: "Build", weeks: 3, focus: "Base"), .init(name: "Taper", weeks: 3, focus: "Recover"),
        ])
        #expect(phases.map(\.weeks) == [1...5, 6...6])
        #expect(phases.last?.isDeload == true)
    }

    @Test func shortPlansDropExtraPhasesAndSkipTheDeload() {
        var brief = TrainingBrief.kneeInjury
        brief.schedule.weeks = 2
        let phases = assembler(brief).phases(from: [
            .init(name: "A", weeks: 1, focus: ""), .init(name: "B", weeks: 1, focus: ""),
            .init(name: "C", weeks: 1, focus: ""),
        ])
        #expect(phases.last?.lastWeek == 2)
        #expect(phases.allSatisfy { !$0.isDeload })
        #expect(phases.reduce(0) { $0 + $1.weeks.count } == 2)
    }

    // MARK: The week

    @Test func legDaysMoveOffTheDayBeforeTheMatch() {
        // Tennis plays a hard match on Saturday and trains Monday, Tuesday, Thursday, Friday.
        let outlines: [PlanBlueprint.DayOutline] = [
            .init(focus: "Upper", kind: "upper strength", intensity: "moderate"),
            .init(focus: "Conditioning", kind: "conditioning", intensity: "moderate"),
            .init(focus: "Speed", kind: "power and speed", intensity: "hard"),
            .init(focus: "Lower", kind: "lower strength", intensity: "hard"),
        ]
        let slots = assembler().arrange(outlines)
        let friday = slots.first { $0.weekday == 5 }!
        #expect(!PlanAssembler.kind(of: friday.outline).isHardOnLegs)
        #expect(slots.map(\.weekday) == [1, 2, 4, 5])
    }

    @Test func requiredKindsAreSwappedIn() {
        let outlines: [PlanBlueprint.DayOutline] = [
            .init(focus: "Lower", kind: "lower strength", intensity: "hard"),
            .init(focus: "Upper", kind: "upper strength", intensity: "hard"),
            .init(focus: "Full", kind: "full body strength", intensity: "hard"),
            .init(focus: "Lower B", kind: "lower strength", intensity: "hard"),
        ]
        let kinds = assembler().balanced(outlines).map(PlanAssembler.kind(of:))
        #expect(kinds.contains(.powerSpeed))
        #expect(kinds.contains(.conditioning))
        #expect(kinds.contains(.upperStrength))

        let beginner = assembler(.weightLossBeginner).balanced(Array(outlines.prefix(3))).map(PlanAssembler.kind(of:))
        #expect(beginner == [.lowerStrength, .upperStrength, .conditioning])
    }

    // MARK: Days

    @Test func daysDropUnknownRepeatedAndUnsafeExercises() {
        let brief = TrainingBrief.kneeInjury
        let built = assembler(brief).templateDay(
            draft(["goblet-squat", "made-up", "goblet-squat", "box-jump", "dumbbell-bench-press"]), kind: .fullBody,
            offered: ExerciseCandidates([]))
        let ids = built.exercises.map(\.exerciseID)
        #expect(!ids.contains("made-up"))
        #expect(!ids.contains("box-jump"), "Jumping is out with a sore knee")
        #expect(Set(ids).count == ids.count)
        #expect(built.report.dropped.contains("made-up"))
    }

    @Test func kitTheyDontHaveIsSwappedForAnAlternative() throws {
        let brief = TrainingBrief.weightLossBeginner
        let barbell = try #require(library.exercise(id: "back-squat"))
        let built = assembler(brief).templateDay(
            draft(["back-squat"]), kind: .lowerStrength, offered: ExerciseCandidates([]))
        if let swapped = built.report.swapped["back-squat"] {
            #expect(built.exercises.map(\.exerciseID) == [swapped])
            #expect(library.exercise(id: swapped)!.isDoable(with: brief.equipment))
        } else {
            #expect(built.exercises.isEmpty)
            #expect(!barbell.isDoable(with: brief.equipment))
        }
    }

    @Test func targetsFollowTheTrackingType() throws {
        let built = assembler().templateDay(
            draft(["back-squat", "plank", "acceleration-sprint", "assault-bike-intervals", "box-jump"], reps: 12),
            kind: .fullBody, offered: ExerciseCandidates([]))
        let byID = Dictionary(uniqueKeysWithValues: built.exercises.map { ($0.exerciseID, $0) })
        #expect(byID["back-squat"]?.sets.first?.reps == 12)
        #expect(byID["back-squat"]?.sets.first?.rpe == 8)
        #expect(byID["plank"]?.sets.first?.seconds == 30)
        #expect(byID["acceleration-sprint"]?.sets.first?.meters == 20)
        let intervals = try #require(byID["assault-bike-intervals"]?.sets)
        #expect(intervals.count == 1)
        #expect(intervals.first?.rounds != nil)
        #expect(byID["box-jump"]?.sets.first?.reps ?? 99 <= 6, "Power work stays at six reps or fewer")
        #expect(byID["back-squat"]?.note == "Brace.")
    }

    @Test func beginnersGetNoRPE() {
        let built = assembler(.weightLossBeginner).templateDay(
            draft(["goblet-squat"]), kind: .lowerStrength, offered: ExerciseCandidates([]))
        #expect(built.exercises.first?.sets.first?.rpe == nil)
        #expect(built.exercises.first?.sets.first?.loadKg == nil, "No known lifts means the first session calibrates")
    }

    @Test func knownLiftsSetLoadableStartingWeights() throws {
        var brief = TrainingBrief.experiencedLifter
        brief.knownLifts = [KnownLift(exerciseID: "back-squat", weightKg: 140, reps: 5)]
        let built = assembler(brief, units: .imperial).templateDay(
            draft(["back-squat"], reps: 5, effort: "hard"), kind: .lowerStrength, offered: ExerciseCandidates([]))
        let set = try #require(built.exercises.first?.sets.first)
        let load = try #require(set.loadKg)
        let pounds = load * Units.poundsPerKilogram
        #expect(abs(pounds - (pounds / 5).rounded() * 5) < 0.01, "Rounded to 5 lb")
        // 140 × 5 is about 163 kg; 5 reps at RPE 8 is about 80%.
        #expect((125...135).contains(load))
        #expect(set.percentOneRepMax != nil)
    }

    @Test func supersetsPairWithThePreviousExercise() {
        let built = assembler().templateDay(
            draft(["bench-press", "pull-up", "pallof-press"], superset: [1]), kind: .upperStrength,
            offered: ExerciseCandidates([]))
        #expect(built.exercises.map(\.supersetGroup) == [1, 1, nil])
    }

    @Test func longDaysAreTrimmedToFit() {
        var brief = TrainingBrief.tennisPlayer
        brief.schedule.sessionMinutes = 30
        let ids = ["back-squat", "bench-press", "pull-up", "romanian-deadlift", "pallof-press", "plank", "dead-bug"]
        let built = assembler(brief).templateDay(draft(ids), kind: .fullBody, offered: ExerciseCandidates([]))
        #expect(PlanAssembler.estimatedMinutes(built.exercises) <= 33)
        #expect(built.exercises.count >= 3)
        #expect(built.report.trimmedSets > 0)
    }

    // MARK: Weeks

    @Test func laterWeeksProgressAndDeloadsEaseOff() throws {
        var brief = TrainingBrief.experiencedLifter
        brief.knownLifts = [KnownLift(exerciseID: "back-squat", weightKg: 150, reps: 3)]
        let assembler = assembler(brief)
        let day = assembler.templateDay(
            draft(["back-squat", "plank"]), kind: .lowerStrength, offered: ExerciseCandidates([]))
        let week1 = try #require(day.exercises.first?.sets.first?.loadKg)
        let week3 = try #require(
            assembler.progressed(day.exercises, weekInPhase: 3, isDeload: false).first?.sets.first?.loadKg)
        let deload = assembler.progressed(day.exercises, weekInPhase: 1, isDeload: true)
        #expect(week3 > week1)
        #expect(try #require(deload.first?.sets.first?.loadKg) < week1)
        #expect(deload.first?.sets.count == day.exercises.first!.sets.count - 1)
        let plank = assembler.progressed(day.exercises, weekInPhase: 3, isDeload: false)[1]
        #expect(plank.sets.first?.seconds == 40)
    }

    @Test func percentOfMaxMatchesTheRPEChart() {
        #expect(abs(PlanAssembler.percentOfMax(reps: 1, rpe: 10) - 0.968) < 0.01)
        #expect(abs(PlanAssembler.percentOfMax(reps: 5, rpe: 8) - 0.811) < 0.01)
    }

    @Test func limitationWordsBecomeAreas() {
        #expect(LimitationRules.areas(mentionedIn: "Sore left knee, and my lower back") == [.knee, .lowerBack])
        #expect(LimitationRules.areas(mentionedIn: "none").isEmpty)
        #expect(TrainingBrief.kneeInjury.limitationAreas.contains(.knee))
    }

    @Test func shortlistsRespectLimitsKitAndSize() {
        let brief = TrainingBrief.kneeInjury
        for kind in DayKind.allCases {
            let offered = DayShortlist.candidates(for: kind, brief: brief)
            #expect(offered.ids.count <= DayShortlist.limit)
            for exercise in offered.exercises {
                #expect(exercise.isDoable(with: brief.equipment))
                #expect(!LimitationRules.excludes(exercise, areas: [.knee]), "\(exercise.id)")
            }
        }
        let tennis = DayShortlist.candidates(for: .powerSpeed, brief: .tennisPlayer)
        #expect(tennis.exercises.contains { $0.sports.contains("tennis") })
        let without = DayShortlist.candidates(for: .powerSpeed, brief: .tennisPlayer, excluding: Set(tennis.ids))
        #expect(Set(without.ids).isDisjoint(with: tennis.ids))
    }
}

struct PlanBrewerTests {
    @Test func brewsAPlanThatPassesTheChecks() async throws {
        let brewer = PlanBrewer(service: PreviewIntelligenceService())
        var plan: BrewedPlan?
        var distilled = 0
        for try await progress in brewer.brew(.tennisPlayer, units: .imperial) {
            switch progress {
            case .distilled: distilled += 1
            case .finished(let finished): plan = finished
            default: break
            }
        }
        let brewed = try #require(plan)
        #expect(distilled == 4 * PlanAssembler.maxTemplates)
        #expect(brewed.days.count == 8 * 4)
        #expect(brewed.phases.last?.isDeload == true)
        #expect(
            PlanCheck.problems(in: brewed, brief: .tennisPlayer).isEmpty,
            "\(PlanCheck.problems(in: brewed, brief: .tennisPlayer))")
        let kinds = Set(brewed.days(inWeek: 1).map(\.kind))
        #expect(kinds.contains(.powerSpeed))
        // Nothing repeats within a week.
        for week in 1...8 {
            let ids = brewed.days(inWeek: week).flatMap { $0.exercises.map(\.exerciseID) }
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test func unavailableIntelligenceFailsPlainly() async {
        let brewer = PlanBrewer(service: PreviewIntelligenceService(availability: .turnedOff))
        await #expect(throws: IntelligenceError.unavailable(.turnedOff)) {
            for try await _ in brewer.brew(.weightLossBeginner, units: .metric) {}
        }
    }

    @Test func promptsFitTheOnDeviceWindow() {
        let brewer = PlanBrewer(service: PreviewIntelligenceService())
        for (_, brief) in TrainingBrief.evaluationSet {
            let blueprint = brewer.blueprintRequest(brief, days: [1, 3, 5])
            #expect(
                ContextBudget.onDevice.fits(
                    promptTokens: ContextBudget.estimatedTokens(in: blueprint.instructions + blueprint.prompt)))
            for kind in DayKind.allCases {
                let offered = DayShortlist.candidates(for: kind, brief: brief)
                let spec = PlanBrewer.DaySpec(
                    phase: PlanPhase(name: "Build", focus: "Base", firstWeek: 1, lastWeek: 3),
                    outline: .init(focus: "Day", kind: kind.rawValue, intensity: "hard"), weekday: 1, kind: kind,
                    earlier: ["Monday: Back squat, Bench press"], beforeMatch: true)
                let day = brewer.dayRequest(brief, spec: spec, offered: offered)
                // The constrained ids add roughly as much again in the schema.
                let tokens = ContextBudget.estimatedTokens(in: day.instructions + day.prompt) + offered.ids.count * 6
                #expect(ContextBudget.onDevice.fits(promptTokens: tokens), "\(kind) \(tokens)")
            }
        }
    }
}

extension PlanAssemblerTests {
    @Test func powerRepsDontClimb() {
        let assembler = assembler()
        let day = assembler.templateDay(
            draft(["box-jump"], reps: 5), kind: .powerSpeed, offered: ExerciseCandidates([]))
        let week4 = assembler.progressed(day.exercises, weekInPhase: 4, isDeload: false)
        #expect(week4.first?.sets.first?.reps == day.exercises.first?.sets.first?.reps)
    }
}
