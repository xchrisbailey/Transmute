import FoundationModels

/// What every AI feature asks for: instructions, a prompt, optional tools, and a structured
/// result. Prompts and schemas are written so another provider could serve them later.
public struct IntelligenceRequest: Sendable {
    public var instructions: String
    public var prompt: String
    /// Makes the tools for one attempt. Tools can keep per-attempt state, such as a search
    /// count, so a retry gets fresh ones.
    public var makeTools: @Sendable () -> [any Tool]
    /// String fields the answer is held to, by property name, e.g. every `exerciseID` to the
    /// ids offered. Enforced while generating, not checked afterwards.
    public var allowedValues: [String: [String]]
    /// Array fields that must have exactly this many items, by property name.
    public var arrayCounts: [String: Int]
    public var temperature: Double?
    public var maximumResponseTokens: Int?

    public init(
        instructions: String, prompt: String, tools: @autoclosure @escaping @Sendable () -> [any Tool] = [],
        allowedValues: [String: [String]] = [:], arrayCounts: [String: Int] = [:], temperature: Double? = nil,
        maximumResponseTokens: Int? = nil
    ) {
        self.arrayCounts = arrayCounts
        self.instructions = instructions
        self.prompt = prompt
        self.makeTools = tools
        self.allowedValues = allowedValues
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }
}

/// One step of a streamed generation: a growing partial result, then the finished one.
public enum GenerationUpdate<Content: Generable & Sendable> {
    case partial(Content.PartiallyGenerated)
    case complete(Content)
}

extension GenerationUpdate: Sendable where Content.PartiallyGenerated: Sendable {}

/// The boundary every AI feature goes through. v1 has one implementation over Apple's
/// Foundation Models; the apps only ever see this protocol, so another provider can be added
/// without touching them.
public protocol IntelligenceService: Sendable {
    /// A short, user-facing name, e.g. "Apple Intelligence".
    var providerName: String { get }

    /// Checked before offering any AI action. Cheap; call it as often as needed.
    var availability: IntelligenceAvailability { get }

    /// Streams partial results as the model writes them, ending with the complete result.
    /// Cancelling the consuming task cancels the generation. Errors are `IntelligenceError`.
    func stream<Content: Generable & Sendable>(_ request: IntelligenceRequest, generating type: Content.Type)
        -> AsyncThrowingStream<GenerationUpdate<Content>, any Error>
}

extension IntelligenceService {
    /// The complete result, without the partial updates.
    public func respond<Content: Generable & Sendable>(
        _ request: IntelligenceRequest, generating type: Content.Type
    ) async throws -> Content {
        for try await update in stream(request, generating: type) {
            if case .complete(let content) = update { return content }
        }
        throw IntelligenceError.malformedOutput
    }
}
