import SwiftUI
import TransmuteCore

extension EnvironmentValues {
    /// Where screens read and write Health data. Defaults to no Health, as on the Mac and in
    /// previews; the iPhone and watch apps set `HealthKitService`.
    @Entry public var health: any HealthService = UnavailableHealthService()
}
