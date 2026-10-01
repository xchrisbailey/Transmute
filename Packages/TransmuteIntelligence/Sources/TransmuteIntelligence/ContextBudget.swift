/// Keeps a request inside the model's context window, leaving room for the response.
///
/// The on-device model has about 8k tokens for instructions, tools, prompt and response
/// together, which is why plans are generated a week at a time (#9).
public struct ContextBudget: Sendable, Equatable {
    public var contextSize: Int
    /// Tokens held back for the model's answer.
    public var responseReserve: Int

    public init(contextSize: Int, responseReserve: Int) {
        self.contextSize = contextSize
        self.responseReserve = responseReserve
    }

    /// The on-device model's window with room for a week of training in the reply.
    public static let onDevice = ContextBudget(contextSize: 8_192, responseReserve: 3_000)

    /// Tokens left for instructions, tool definitions and the prompt.
    public var promptAllowance: Int {
        max(0, contextSize - responseReserve)
    }

    public func fits(promptTokens: Int) -> Bool {
        promptTokens <= promptAllowance
    }

    /// A rough count for when the real tokenizer isn't available, e.g. in tests or before the
    /// model has downloaded. English averages about four characters a token; this rounds up so
    /// estimates err on the safe side.
    public static func estimatedTokens(in text: String) -> Int {
        (text.utf8.count + 2) / 3
    }
}
