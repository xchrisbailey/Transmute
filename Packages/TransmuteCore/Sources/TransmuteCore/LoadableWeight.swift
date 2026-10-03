/// Rounds a target load to one you can actually put on the bar or pick off the rack.
///
/// Without an inventory it rounds to a typical step, which is what plans are brewed with. With
/// the person's own `PlateInventory` (#21) it rounds to what their bar, plates, dumbbells and
/// machines can really make; progression (#12) uses that.
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

    /// The nearest weight this kit can make, in kilograms.
    ///
    /// Barbell work (a trap bar when the exercise uses one) rounds to what the plates load,
    /// never below the bar. Dumbbells and kettlebells round to the dumbbell step, from one step
    /// to the heaviest. Machines, cables and sleds round to the stack step. Anything else falls
    /// back to `round(_:for:system:)` in the kit's unit.
    public static func round(_ kg: Double, for equipment: Set<Equipment>, inventory: PlateInventory) -> Double {
        if equipment.contains(.trapBar) {
            return PlateCalculator(inventory: inventory, bar: .trap).nearestKg(kg)
        }
        if equipment.contains(.barbell) {
            return PlateCalculator(inventory: inventory).nearestKg(kg)
        }
        if !equipment.isDisjoint(with: [.dumbbell, .kettlebell]) {
            return steps(kg, step: inventory.dumbbellStepKg, heaviest: inventory.heaviestDumbbellKg, in: inventory)
        }
        if !equipment.isDisjoint(with: [.machine, .cable, .sled]) {
            return steps(kg, step: inventory.machineStepKg, heaviest: nil, in: inventory)
        }
        return round(kg, for: equipment, system: inventory.system)
    }

    /// The nearest whole number of steps, worked in the kit's unit so pound steps stay exact.
    private static func steps(_ kg: Double, step: Double, heaviest: Double?, in inventory: PlateInventory) -> Double {
        let step = inventory.hundredths(kg: step)
        guard step > 0 else { return kg }
        let most = heaviest.map { max(1, inventory.hundredths(kg: $0) / step) } ?? .max
        let count = min(most, max(1, Int((Double(inventory.hundredths(kg: kg)) / Double(step)).rounded())))
        return inventory.kilograms(hundredths: count * step)
    }
}
