import TransmuteCore

/// The plan-generation boundary. Foundation Models sits behind this in #8, so other
/// providers can be added later without touching the apps.
public protocol PlanBrewer: Sendable {
    /// A short, user-facing name for where plans are brewed, e.g. "Apple Intelligence".
    var providerName: String { get }
}
