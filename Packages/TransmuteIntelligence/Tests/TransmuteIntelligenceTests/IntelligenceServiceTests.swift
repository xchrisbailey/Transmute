import Foundation
import FoundationModels
import Testing
import TransmuteCore

@testable import TransmuteIntelligence

struct IntelligenceServiceTests {
    @Test func mapsSystemAvailability() {
        typealias Service = FoundationModelsService
        #expect(Service.availability(of: .available) == .available)
        #expect(Service.availability(of: .unavailable(.deviceNotEligible)) == .deviceNotEligible)
        #expect(Service.availability(of: .unavailable(.appleIntelligenceNotEnabled)) == .turnedOff)
        #expect(Service.availability(of: .unavailable(.modelNotReady)) == .modelNotReady)
    }

    @Test func onlyAvailableGenerates() {
        #expect(IntelligenceAvailability.available.canGenerate)
        for state in [IntelligenceAvailability.deviceNotEligible, .turnedOff, .modelNotReady] {
            #expect(!state.canGenerate)
        }
        #expect(IntelligenceAvailability.modelNotReady.resolvesOnItsOwn)
        #expect(!IntelligenceAvailability.turnedOff.resolvesOnItsOwn)
    }

    @Test func mapsProviderErrors() {
        typealias Service = FoundationModelsService
        let exceeded = LanguageModelError.contextSizeExceeded(
            .init(contextSize: 8_192, tokenCount: 9_000, debugDescription: ""))
        #expect(Service.map(exceeded) == .tooLong)
        #expect(Service.map(LanguageModelError.guardrailViolation(.init(debugDescription: ""))) == .guardrail)
        #expect(
            Service.map(LanguageModelError.refusal(.init(explanation: "No", debugDescription: "")))
                == .refused(explanation: nil))
        #expect(
            Service.map(LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: ""))) == .rateLimited)
        #expect(Service.map(IntelligenceError.tooLong) == .tooLong)
        guard case .failed = Service.map(CocoaError(.fileNoSuchFile)) else {
            Issue.record("Unknown errors should map to failed")
            return
        }
    }

    @Test func routeDefaultsToOnDeviceAndRoundTrips() throws {
        let defaults = try #require(UserDefaults(suiteName: "IntelligenceServiceTests.\(UUID())"))
        #expect(IntelligenceSettings.load(from: defaults).route == .onDeviceOnly)
        IntelligenceSettings(route: .allowPrivateCloudCompute).save(to: defaults)
        #expect(IntelligenceSettings.load(from: defaults).route == .allowPrivateCloudCompute)
    }

    @Test func stubServiceStreamsThenCompletes() async throws {
        let service = StubService(result: WarmUpProbe(title: "Warm", moves: []))
        var partials = 0
        var complete: WarmUpProbe?
        for try await update in service.stream(WarmUpProbe.request(focus: "legs"), generating: WarmUpProbe.self) {
            switch update {
            case .partial: partials += 1
            case .complete(let content): complete = content
            }
        }
        #expect(partials == 1)
        #expect(complete?.title == "Warm")
        #expect(
            try await service.respond(WarmUpProbe.request(focus: "legs"), generating: WarmUpProbe.self).title == "Warm")
    }
}

/// Plays back a fixed result, the way tests and previews stand in for the model.
struct StubService: IntelligenceService {
    let providerName = "Stub"
    let availability = IntelligenceAvailability.available
    let result: WarmUpProbe

    func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
    {
        AsyncThrowingStream { continuation in
            let content = result as! Content  // swiftlint:disable:this force_cast
            continuation.yield(.partial(content.asPartiallyGenerated()))
            continuation.yield(.complete(content))
            continuation.finish()
        }
    }
}
