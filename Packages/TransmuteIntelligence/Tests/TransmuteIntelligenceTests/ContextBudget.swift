/// Keeps a request inside the model's context window, leaving room for the response.
///
/// The on-device model has about 8k tokens for instructions, tools, prompt and response
/// together.
struct ContextBudget: Sendable, Equatable {
    var contextSize: Int
    /// Tokens held back for the model's answer.
    var responseReserve: Int

    /// The on-device model's window with room for the reply.
    static let onDevice = ContextBudget(contextSize: 8_192, responseReserve: 3_000)

    /// Tokens left for instructions, tool definitions and the prompt.
    var promptAllowance: Int {
        max(0, contextSize - responseReserve)
    }

    func fits(promptTokens: Int) -> Bool {
        promptTokens <= promptAllowance
    }

    /// A rough count for when the real tokenizer isn't available, e.g. in tests or before the
    /// model has downloaded. English averages about four characters a token; this rounds up so
    /// estimates err on the safe side.
    static func estimatedTokens(in text: String) -> Int {
        (text.utf8.count + 2) / 3
    }
}
