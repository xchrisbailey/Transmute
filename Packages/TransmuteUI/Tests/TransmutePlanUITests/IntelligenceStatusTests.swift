import FoundationModels
import Testing
import TransmuteIntelligence
import TransmuteUI

@testable import TransmutePlanUI

@MainActor
struct IntelligenceStatusTests {
    @Test func picksUpTheModelOnceItFinishesDownloading() async {
        let service = ModelFinishesDownloadingService()
        let status = IntelligenceStatus(service: service)
        #expect(status.availability == .modelNotReady)
        await status.watch(every: .milliseconds(1))
        #expect(status.availability == .available)
    }

    @Test func everyFailureHasPlainCopy() {
        let errors: [IntelligenceError] = [
            .unavailable(.turnedOff), .unavailable(.modelNotReady), .unavailable(.deviceNotEligible),
            .refused(explanation: nil), .guardrail, .tooLong, .rateLimited, .unsupportedLanguage, .searchLoop,
            .malformedOutput, .failed(detail: "x"),
        ]
        for error in errors {
            #expect(error.message.key.hasPrefix("plain."), "\(error)")
        }
    }
}

final class ModelFinishesDownloadingService: IntelligenceService, @unchecked Sendable {
    let providerName = "Stub"
    private var checks = 0

    var availability: IntelligenceAvailability {
        checks += 1
        return checks > 3 ? .available : .modelNotReady
    }

    func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
    {
        AsyncThrowingStream { $0.finish(throwing: IntelligenceError.unavailable(.modelNotReady)) }
    }
}
