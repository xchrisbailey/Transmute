import Foundation
import FoundationModels
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct SchemaConstraintTests {
    func json(_ schema: GenerationSchema) throws -> String {
        try #require(String(bytes: JSONEncoder().encode(schema), encoding: .utf8))
    }

    @Test func restrictsNestedStringFields() throws {
        let schema = try SchemaConstraint.restrict(
            WarmUpProbe.generationSchema, allowedValues: ["exerciseID": ["back-squat", "hip-90-90"]])
        let text = try json(schema)
        #expect(text.contains(#""enum":["back-squat","hip-90-90"]"#))
        #expect(!text.contains(#""enum":["back-squat","hip-90-90"],"title":"A short title"#))
    }

    @Test func restrictsStringArrays() throws {
        let schema = try SchemaConstraint.restrict(
            ListProbe.generationSchema, allowedValues: ["exerciseIDs": ["a", "b"]])
        #expect(try json(schema).contains(#""enum":["a","b"]"#))
    }

    @Test func leavesSchemasAloneWithoutConstraints() throws {
        let schema = try SchemaConstraint.restrict(WarmUpProbe.generationSchema, allowedValues: [:])
        #expect(!(try json(schema)).contains("enum"))
    }

    @Test func candidatesListEveryIDOnceByCategory() {
        let candidates = ExerciseCandidates(
            scope: TrainingBrief.weightLossBeginner.exerciseScope, excluding: ["goblet-squat"])
        #expect(!candidates.ids.isEmpty)
        #expect(!candidates.ids.contains("goblet-squat"))
        #expect(Set(candidates.ids).count == candidates.ids.count)
        for id in candidates.ids {
            #expect(candidates.promptList.contains("\(id): "))
        }
        #expect(candidates.constraint["exerciseID"] == candidates.ids)
    }
}

@Generable
struct ListProbe {
    var exerciseIDs: [String]
}
