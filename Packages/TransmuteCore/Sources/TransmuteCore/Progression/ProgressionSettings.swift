/// How progression adds load, and which exercises it leaves alone (#12). Stored on the profile.
///
/// Increments are kept in each unit system's own unit, so 2.5 kg and 5 lb stay round numbers
/// whichever the person switches to.
public struct ProgressionSettings: Codable, Hashable, Sendable {
    /// Kilograms added to an upper-body lift when it moves up, in metric.
    public var upperBodyKg: Double
    /// Kilograms added to a lower-body lift when it moves up, in metric.
    public var lowerBodyKg: Double
    /// Pounds added to an upper-body lift when it moves up, in imperial.
    public var upperBodyLb: Double
    /// Pounds added to a lower-body lift when it moves up, in imperial.
    public var lowerBodyLb: Double
    /// Exercises whose targets stay where they are until the person lets them go.
    public var heldExerciseIDs: [String]

    public init(
        upperBodyKg: Double = 1.25, lowerBodyKg: Double = 2.5, upperBodyLb: Double = 2.5, lowerBodyLb: Double = 5,
        heldExerciseIDs: [String] = []
    ) {
        self.upperBodyKg = upperBodyKg
        self.lowerBodyKg = lowerBodyKg
        self.upperBodyLb = upperBodyLb
        self.lowerBodyLb = lowerBodyLb
        self.heldExerciseIDs = heldExerciseIDs
    }

    /// The choices offered for an increment, in the system's own unit.
    public static func incrementChoices(for system: UnitSystem) -> [Double] {
        system == .metric ? [0.5, 1, 1.25, 2, 2.5, 5] : [1, 2.5, 5, 10]
    }

    /// The increment in the system's own unit.
    public func increment(for region: BodyRegion, system: UnitSystem) -> Double {
        switch (system, region) {
        case (.metric, .upper): upperBodyKg
        case (.metric, .lower): lowerBodyKg
        case (.imperial, .upper): upperBodyLb
        case (.imperial, .lower): lowerBodyLb
        }
    }

    /// Sets the increment in the system's own unit.
    public mutating func setIncrement(_ value: Double, for region: BodyRegion, system: UnitSystem) {
        switch (system, region) {
        case (.metric, .upper): upperBodyKg = value
        case (.metric, .lower): lowerBodyKg = value
        case (.imperial, .upper): upperBodyLb = value
        case (.imperial, .lower): lowerBodyLb = value
        }
    }

    /// The increment in kilograms, for the engine.
    public func incrementKg(for region: BodyRegion, system: UnitSystem) -> Double {
        let value = increment(for: region, system: system)
        return system == .metric ? value : value / Units.poundsPerKilogram
    }

    public func isHeld(_ exerciseID: String) -> Bool {
        heldExerciseIDs.contains(exerciseID)
    }

    /// Holds or releases one exercise, for the session's "Hold this weight".
    public mutating func toggleHold(_ exerciseID: String) {
        setHeld(!isHeld(exerciseID), exerciseID)
    }

    public mutating func setHeld(_ held: Bool, _ exerciseID: String) {
        heldExerciseIDs.removeAll { $0 == exerciseID }
        if held { heldExerciseIDs.append(exerciseID) }
    }
}

/// Which half of the body a lift mostly loads, which decides its increment.
public enum BodyRegion: String, Codable, CaseIterable, Sendable {
    case upper, lower

    private static let lowerMuscles: Set<Muscle> = [
        .quads, .hamstrings, .glutes, .adductors, .abductors, .calves, .hipFlexors,
    ]

    /// Squats, hinges, lunges and carries are lower body; pushes and pulls are upper body.
    /// Anything else goes by its primary muscles. Unknown exercises get the smaller upper-body
    /// step, which is the safer guess.
    public init(_ exercise: LibraryExercise?) {
        guard let exercise else {
            self = .upper
            return
        }
        switch exercise.pattern {
        case .squat, .hinge, .lunge, .carry, .jump, .sprint, .locomotion:
            self = .lower
        case .horizontalPush, .verticalPush, .horizontalPull, .verticalPull:
            self = .upper
        default:
            let muscles = Set(exercise.primaryMuscles)
            self = muscles.isDisjoint(with: Self.lowerMuscles) && !muscles.contains(.fullBody) ? .upper : .lower
        }
    }
}

extension Profile {
    /// Holds or releases one exercise's targets, for the session's "Hold this weight".
    public func toggleProgressionHold(for exerciseID: String) {
        progression.toggleHold(exerciseID)
    }
}
