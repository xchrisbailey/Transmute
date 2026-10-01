import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct ExerciseLookupToolTests {
    let library = ExerciseLibrary.bundled

    @Test func findsByNameWithRealIDs() async throws {
        let tool = ExerciseLookupTool(library: library)
        let output = try await tool.call(arguments: .init(search: "back squat"))
        #expect(output.hasPrefix("back-squat: Back squat"))
        for line in output.split(separator: "\n") {
            let id = String(line.prefix { $0 != ":" })
            #expect(library.exercise(id: id) != nil, "\(id)")
        }
    }

    @Test func staysInsideTheScope() {
        let brief = TrainingBrief.weightLossBeginner
        let tool = ExerciseLookupTool(library: library, scope: brief.exerciseScope, maxResults: 100)
        let results = tool.search(.init(search: "", category: "strength"))
        #expect(!results.isEmpty)
        for exercise in results {
            #expect(exercise.isDoable(with: brief.equipment), "\(exercise.id)")
            #expect(exercise.difficulty == .beginner, "\(exercise.id)")
            #expect(exercise.category == .strength)
        }
    }

    @Test func neverReturnsExcludedIDs() {
        let tool = ExerciseLookupTool(library: library, excludedIDs: ["back-squat"])
        #expect(!tool.search(.init(search: "back squat")).contains { $0.id == "back-squat" })
    }

    @Test func fallsBackToFiltersWhenWordsMatchNothing() {
        let tool = ExerciseLookupTool(library: library)
        let results = tool.search(.init(search: "zzqx", category: "mobility"))
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.category == .mobility })
    }

    @Test func caps() {
        #expect(ExerciseLookupTool(library: library, maxResults: 3).search(.init(search: "")).count == 3)
    }
}

extension ExerciseLookupToolTests {
    @Test func stopsTheModelSearchingForever() async throws {
        let tool = ExerciseLookupTool(library: library, maxCalls: 2)
        _ = try await tool.call(arguments: .init(search: "squat"))
        _ = try await tool.call(arguments: .init(search: "squat"))
        await #expect(throws: ExerciseLookupTool.SearchLimitReached.self) {
            try await tool.call(arguments: .init(search: "squat"))
        }
        #expect(tool.callCount == 3)
    }
}
