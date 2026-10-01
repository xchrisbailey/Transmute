import Testing

@testable import TransmuteIntelligence

struct PlanBrewerTests {
    struct StubBrewer: PlanBrewer {
        let providerName = "Stub"
    }

    @Test func brewerExposesProviderName() {
        #expect(StubBrewer().providerName == "Stub")
    }
}
