import Foundation
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct PlanAssemblerPhaseTests {
    func assembler(_ brief: TrainingBrief) -> PlanAssembler {
        PlanAssembler(brief: brief, units: .metric, library: .bundled)
    }

    @Test func everyBlueprintFitsEveryPlanLengthWithoutOverlap() {
        let lengthSets = [[1, 1, 1, 1], [2, 5, 1, 3], [4, 4, 4, 4], [1, 6, 2, 9]]
        var failures: [String] = []
        for count in 1...4 {
            for trailingDeload in [false, true] {
                for requested in lengthSets {
                    var blueprint = requested.prefix(count).enumerated().map {
                        PlanBlueprint.Phase(name: "Phase \($0.offset)", weeks: $0.element, focus: "Work")
                    }
                    if trailingDeload { blueprint.append(.init(name: "Deload", weeks: 1, focus: "Recover")) }
                    for weeks in 1...12 {
                        var brief = TrainingBrief.tennisPlayer
                        brief.schedule.weeks = weeks
                        let phases = assembler(brief).phases(from: blueprint)
                        let contiguous = zip(phases, phases.dropFirst()).allSatisfy { $1.firstWeek == $0.lastWeek + 1 }
                        let covers = phases.first?.firstWeek == 1 && phases.last?.lastWeek == weeks
                        let deloadsOnlyLast = phases.dropLast().allSatisfy { !$0.isDeload }
                        let deloadIsOneWeek = phases.last.map { !$0.isDeload || $0.weeks == weeks...weeks } ?? false
                        if !(contiguous && covers && deloadsOnlyLast && deloadIsOneWeek) {
                            failures.append(
                                "\(count) phases, deload \(trailingDeload), \(requested.prefix(count)), \(weeks) weeks: "
                                    + phases.map { "\($0.name) \($0.firstWeek)-\($0.lastWeek)" }.joined(separator: ", ")
                            )
                        }
                    }
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test func aOneWeekPlanKeepsTheMainPhaseAndDropsTheDeload() {
        var brief = TrainingBrief.tennisPlayer
        brief.schedule.weeks = 1
        let phases = assembler(brief).phases(from: [
            .init(name: "Build", weeks: 3, focus: "Base"), .init(name: "Deload", weeks: 1, focus: "Recover"),
        ])
        #expect(phases.map(\.name) == ["Build"])
        #expect(phases.map(\.weeks) == [1...1])
        #expect(phases.allSatisfy { !$0.isDeload })
    }
}
