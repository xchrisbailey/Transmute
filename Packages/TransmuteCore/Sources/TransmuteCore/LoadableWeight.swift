/// Rounds a target load to one you can actually put on the bar or pick off the rack. The full
/// plate calculator is #21; this is the step size plans round to.
public enum LoadableWeight {
    /// The smallest jump for this kit, in kilograms: 2.5 kg or 5 lb for barbells and machines
    /// (two small plates), 2 kg or 5 lb for dumbbells and kettlebells.
    public static func step(for equipment: Set<Equipment>, system: UnitSystem) -> Double {
        switch system {
        case .imperial:
            5 / Units.poundsPerKilogram
        case .metric:
            equipment.isDisjoint(with: [.barbell, .trapBar, .machine, .cable, .landmine, .sled]) ? 2 : 2.5
        }
    }

    /// The nearest loadable weight in kilograms, never below one step.
    public static func round(_ kg: Double, for equipment: Set<Equipment>, system: UnitSystem) -> Double {
        let step = step(for: equipment, system: system)
        let display = system == .metric ? kg : kg * Units.poundsPerKilogram
        let displayStep = system == .metric ? step : 5
        let rounded = max(displayStep, (display / displayStep).rounded() * displayStep)
        return system == .metric ? rounded : rounded / Units.poundsPerKilogram
    }
}
