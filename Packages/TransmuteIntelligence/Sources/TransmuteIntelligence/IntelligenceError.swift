import Foundation

/// Why a generation failed, mapped from whatever the provider threw.
public enum IntelligenceError: Error, Equatable, Sendable {
    /// The model can't be used right now.
    case unavailable(IntelligenceAvailability)
    /// The model declined the request, e.g. it read as medical advice. The explanation is the
    /// model's own, when it gave one.
    case refused(explanation: String?)
    /// The provider's safety filter blocked the prompt or the response.
    case guardrail
    /// The request didn't fit the model's context window. Callers should split it further.
    case tooLong
    /// Too many requests in a short time, or a Private Cloud Compute quota was reached.
    case rateLimited
    /// The device language isn't one the model supports.
    case unsupportedLanguage
    /// The model kept calling a tool instead of answering.
    case searchLoop
    /// The output didn't parse into the requested structure.
    case malformedOutput
    /// Anything else. The detail is for logs, not for people.
    case failed(detail: String)

    /// Failures a fresh attempt often gets past, because the model went off track rather than
    /// the request being wrong.
    public var isWorthRetrying: Bool {
        switch self {
        case .searchLoop, .tooLong, .malformedOutput, .refused: true
        default: false
        }
    }
}

extension IntelligenceError: LocalizedError {
    /// For logs and test reports. People see plain copy chosen by the screen instead (#3).
    public var errorDescription: String? {
        String(describing: self)
    }
}
