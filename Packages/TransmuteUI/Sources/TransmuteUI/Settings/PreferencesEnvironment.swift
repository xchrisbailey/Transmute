import SwiftUI
import TransmuteCore

extension EnvironmentValues {
    /// Whether set rows and plan screens show RPE and %1RM (#18). Defaults to both, as in
    /// previews; the apps set it from the profile with `workoutPreferences(of:)`.
    @Entry public var effortDisplay: EffortDisplay = .everything
}

extension View {
    /// Hands the profile's display preferences to every screen below, sheets included.
    public func workoutPreferences(of profile: Profile?) -> some View {
        environment(\.effortDisplay, EffortDisplay(profile))
    }
}
