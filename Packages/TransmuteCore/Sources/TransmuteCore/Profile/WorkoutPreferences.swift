import Foundation
import SwiftData

/// How a workout runs and what its screens show (#18). Stored on the profile, so it syncs
/// with everything else.
public struct WorkoutPreferences: Codable, Hashable, Sendable {
    /// Rest after a working set that has no rest of its own, in seconds.
    public var workingRestSeconds: Double
    /// Rest after a warm-up set that has no rest of its own, in seconds.
    public var warmUpRestSeconds: Double
    /// Plays a sound when rest ends, in the app and on its notification.
    public var restSound: Bool
    /// Taps when rest ends, on the iPhone and on the wrist.
    public var restHaptics: Bool
    /// Starts the rest timer as soon as a set is logged.
    public var autoStartRest: Bool
    /// Shows RPE, how hard a set felt. `nil` until chosen, which follows experience.
    public var showRPE: Bool?
    /// Shows loads as a percentage of 1RM. `nil` until chosen, which follows experience.
    public var showPercentOfMax: Bool?
    /// Adds warm-up sets to barbell lifts and keeps the ones a plan has. Off leaves them all out.
    public var warmUpSets: Bool

    public init(
        workingRestSeconds: Double = 90, warmUpRestSeconds: Double = 45, restSound: Bool = true,
        restHaptics: Bool = true, autoStartRest: Bool = true, showRPE: Bool? = nil, showPercentOfMax: Bool? = nil,
        warmUpSets: Bool = true
    ) {
        self.workingRestSeconds = workingRestSeconds
        self.warmUpRestSeconds = warmUpRestSeconds
        self.restSound = restSound
        self.restHaptics = restHaptics
        self.autoStartRest = autoStartRest
        self.showRPE = showRPE
        self.showPercentOfMax = showPercentOfMax
        self.warmUpSets = warmUpSets
    }

    /// The rest times offered in Settings, in seconds.
    public static let restChoices: [Double] = [30, 45, 60, 90, 120, 150, 180, 240, 300]

    /// The rest for a set that doesn't carry one.
    public func restSeconds(isWarmUp: Bool) -> Double {
        isWarmUp ? warmUpRestSeconds : workingRestSeconds
    }

    /// Whether RPE is shown. Until chosen it's hidden for beginners, who have enough to learn
    /// already, and shown to everyone else.
    public func showsRPE(for experience: ExperienceLevel) -> Bool {
        showRPE ?? (experience != .beginner)
    }

    /// Whether %1RM is shown, with the same rule as RPE.
    public func showsPercentOfMax(for experience: ExperienceLevel) -> Bool {
        showPercentOfMax ?? (experience != .beginner)
    }

    /// The stored preferences: the first profile's, or the defaults before there is one.
    public static func stored(in context: ModelContext?) -> WorkoutPreferences {
        var descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return (try? context?.fetch(descriptor))?.first?.preferences ?? WorkoutPreferences()
    }
}

/// Which of the effort terms a screen shows next to a set: RPE and %1RM (#18).
public struct EffortDisplay: Hashable, Sendable {
    public var showsRPE: Bool
    public var showsPercentOfMax: Bool

    public init(showsRPE: Bool, showsPercentOfMax: Bool) {
        self.showsRPE = showsRPE
        self.showsPercentOfMax = showsPercentOfMax
    }

    /// What a profile asks for. With no profile, what a beginner sees.
    public init(_ profile: Profile?) {
        let preferences = profile?.preferences ?? WorkoutPreferences()
        let experience = profile?.experience ?? .beginner
        self.init(
            showsRPE: preferences.showsRPE(for: experience),
            showsPercentOfMax: preferences.showsPercentOfMax(for: experience))
    }

    /// Both shown.
    public static let everything = EffortDisplay(showsRPE: true, showsPercentOfMax: true)
}
