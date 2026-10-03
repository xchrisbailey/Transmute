import Foundation
import FoundationModels
import OSLog

#if !os(watchOS)
    /// `IntelligenceService` over Apple's Foundation Models: the on-device model by default,
    /// Private Cloud Compute when the user allows it and it's reachable.
    public struct FoundationModelsService: IntelligenceService {
        public let providerName = "Apple Intelligence"
        /// A fixed choice, for tests. `nil` reads the person's choice each time a generation
        /// starts, so a change in Settings (#18) applies straight away.
        public var settings: IntelligenceSettings?

        public init(settings: IntelligenceSettings? = nil) {
            self.settings = settings
        }

        /// Where the next generation may run.
        var route: ModelRoute {
            (settings ?? .load()).route
        }

        public var availability: IntelligenceAvailability {
            Self.availability(of: SystemLanguageModel.default.availability)
        }

        static func availability(of availability: SystemLanguageModel.Availability) -> IntelligenceAvailability {
            switch availability {
            case .available: .available
            case .unavailable(.deviceNotEligible): .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled): .turnedOff
            case .unavailable(.modelNotReady): .modelNotReady
            case .unavailable: .modelNotReady
            }
        }

        /// The on-device context window, in tokens.
        public var contextSize: Int {
            SystemLanguageModel.default.contextSize
        }

        public func stream<Content: Generable & Sendable>(
            _ request: IntelligenceRequest, generating type: Content.Type
        ) -> AsyncThrowingStream<GenerationUpdate<Content>, any Error> {
            let availability = self.availability
            let service = self
            return AsyncThrowingStream { continuation in
                guard availability.canGenerate else {
                    continuation.finish(throwing: IntelligenceError.unavailable(availability))
                    return
                }
                let task = Task {
                    var attempt = 1
                    while true {
                        var yieldedPartial = false
                        do {
                            let content = try await service.generate(request, generating: type) { partial in
                                yieldedPartial = true
                                continuation.yield(.partial(partial))
                            }
                            continuation.yield(.complete(content))
                            continuation.finish()
                            return
                        } catch is CancellationError {
                            continuation.finish(throwing: CancellationError())
                            return
                        } catch {
                            let mapped = await Self.mapWithExplanation(error)
                            Self.logger.error(
                                "Attempt \(attempt) failed: \(String(describing: error), privacy: .public)")
                            // Retry once from scratch when the model went off track before showing
                            // anything, so the screen never jumps back.
                            guard attempt < Self.maxAttempts, mapped.isWorthRetrying, !yieldedPartial else {
                                continuation.finish(throwing: mapped)
                                return
                            }
                            attempt += 1
                        }
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        static let maxAttempts = 2

        /// One attempt in a fresh session, reporting partial results as they arrive.
        func generate<Content: Generable & Sendable>(
            _ request: IntelligenceRequest, generating type: Content.Type,
            onPartial: (sending Content.PartiallyGenerated) -> Void
        ) async throws -> Content {
            let session = makeSession(request)
            let options = GenerationOptions(
                temperature: request.temperature, maximumResponseTokens: request.maximumResponseTokens)
            let schema = try SchemaConstraint.restrict(
                Content.generationSchema, allowedValues: request.allowedValues, arrayCounts: request.arrayCounts)
            let stream = session.streamResponse(to: Prompt(request.prompt), schema: schema, options: options)
            for try await snapshot in stream {
                // Rebuilt from the Sendable raw content so each partial is independent of the stream.
                onPartial(try Content.PartiallyGenerated(snapshot.rawContent))
            }
            return try Content(try await stream.collect().content)
        }

        func makeSession(_ request: IntelligenceRequest) -> LanguageModelSession {
            if route == .allowPrivateCloudCompute {
                let cloud = PrivateCloudComputeLanguageModel()
                if cloud.isAvailable {
                    return LanguageModelSession(
                        model: cloud, tools: request.makeTools(), instructions: request.instructions)
                }
            }
            return LanguageModelSession(tools: request.makeTools(), instructions: request.instructions)
        }

        /// Counts tokens with the on-device tokenizer, for budgeting requests.
        public func tokenCount(instructions: String, prompt: String, tools: [any Tool] = []) async throws -> Int {
            let model = SystemLanguageModel.default
            let fixed = try await model.tokenCount(for: Instructions(instructions)) + model.tokenCount(for: tools)
            return try await fixed + model.tokenCount(for: Prompt(prompt))
        }

        private static let logger = Logger(subsystem: "computer.srcery.transmute", category: "intelligence")

        /// `map`, plus the model's own words when it refused.
        static func mapWithExplanation(_ error: any Error) async -> IntelligenceError {
            if case .refusal(let refusal) = error as? LanguageModelError {
                return .refused(explanation: try? await refusal.explanation.content)
            }
            return map(error)
        }

        /// Translates Foundation Models errors into provider-neutral ones.
        static func map(_ error: any Error) -> IntelligenceError {
            if let error = error as? IntelligenceError { return error }
            if let error = error as? LanguageModelError { return map(error) }
            if let error = error as? LanguageModelSession.ToolCallError {
                return error.underlyingError is ExerciseLookupTool.SearchLimitReached
                    ? .searchLoop : .failed(detail: String(describing: error))
            }
            if let error = error as? PrivateCloudComputeLanguageModel.Error {
                if case .quotaLimitReached = error { return .rateLimited }
                return .failed(detail: String(describing: error))
            }
            return .failed(detail: String(describing: error))
        }

        static func map(_ error: LanguageModelError) -> IntelligenceError {
            switch error {
            case .contextSizeExceeded: .tooLong
            case .rateLimited: .rateLimited
            case .guardrailViolation: .guardrail
            case .refusal: .refused(explanation: nil)
            case .unsupportedLanguageOrLocale: .unsupportedLanguage
            default: .failed(detail: String(describing: error))
            }
        }
    }
#endif
