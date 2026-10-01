/// Whether plans can be brewed right now, in words that don't depend on the provider.
public enum IntelligenceAvailability: Equatable, Sendable {
    case available
    /// This device can't run Apple Intelligence. Transmute requires one, so this blocks.
    case deviceNotEligible
    /// Apple Intelligence is turned off in Settings. Plans and logging still work; brewing and
    /// reworking wait until it's back on.
    case turnedOff
    /// The model is still downloading. Resumes on its own.
    case modelNotReady

    public var canGenerate: Bool {
        self == .available
    }

    /// Whether waiting is enough for this to become available, without the user doing anything.
    public var resolvesOnItsOwn: Bool {
        self == .modelNotReady
    }
}
