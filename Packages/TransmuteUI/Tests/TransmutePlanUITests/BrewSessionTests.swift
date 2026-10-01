import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteIntelligence

@testable import TransmutePlanUI

@MainActor
struct BrewSessionTests {
    func finish(_ session: BrewSession) async {
        for _ in 0..<500 where session.isBrewing {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func brewsPreviewsAndKeepsAsTheOnlyActivePlan() async throws {
        let container = try TransmuteStore.makeContainer(.inMemory)
        let context = container.mainContext
        let (_, old) = SampleData.insert(into: context)
        try context.save()

        let session = BrewSession(brewer: PlanBrewer(service: PreviewIntelligenceService()))
        session.start(.tennisPlayer, units: .imperial)
        #expect(session.isBrewing)
        await finish(session)
        guard case .preview(let preview) = session.state else {
            Issue.record("Expected a preview, got \(session.state)")
            return
        }
        #expect(session.distilled.count == 8)
        #expect(session.planName == preview.name)
        #expect(try context.fetchCount(FetchDescriptor<Plan>()) == 1, "Nothing is saved before keeping")

        let monday = Date(timeIntervalSince1970: 1_790_640_000)  // A Wednesday in 2026.
        let plan = try #require(try session.keep(in: context, startDate: monday, device: "iPhone"))
        #expect(plan.isActive)
        #expect(!old.isActive)
        #expect(plan.brewedBy == "Apple Intelligence on iPhone")
        #expect(plan.orderedDays.count == 32)
        #expect(plan.phases == preview.phases)
        #expect(Calendar(identifier: .iso8601).component(.weekday, from: plan.startDate) == 2, "Starts on a Monday")
        #expect(session.state == .idle)
    }

    @Test func failuresArePlain() async {
        let session = BrewSession(brewer: PlanBrewer(service: PreviewIntelligenceService(availability: .turnedOff)))
        session.start(.weightLossBeginner, units: .metric)
        await finish(session)
        #expect(session.state == .failed(.unavailable(.turnedOff)))
    }

    @Test func cancellingGoesBackToTheStart() async {
        let session = BrewSession(brewer: PlanBrewer(service: PreviewIntelligenceService()))
        session.start(.tennisPlayer, units: .metric)
        session.cancel()
        #expect(session.state == .idle)
        #expect(session.distilled.isEmpty)
    }

    @Test func targetsReadAsOneLine() {
        let units = Units(system: .metric)
        let lift = BrewedSet(reps: 5, loadKg: 100, rpe: 8, restSeconds: 180)
        #expect(SetTargets([lift, lift, lift]).summary(units: units) == "3 × 5 · 100 kg · RPE 8")
        let intervals = BrewedSet(seconds: 20, restSeconds: 60, rounds: 8, intervalRestSeconds: 10)
        #expect(SetTargets([intervals]).summary(units: units) == "8 × 0:20 / 0:10")
        let plank = BrewedSet(seconds: 45, restSeconds: 30)
        #expect(SetTargets([plank, plank]).summary(units: units) == "2 × 0:45")
    }
}
