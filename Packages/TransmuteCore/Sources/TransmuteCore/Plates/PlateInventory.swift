import Foundation

/// The bars a gym or home set might have. Each has its own weight in the inventory.
public enum BarKind: String, Codable, CaseIterable, Sendable {
    /// The usual Olympic bar: 20 kg or 45 lb.
    case standard
    /// A lighter Olympic bar: 15 kg or 35 lb.
    case light
    /// A short cambered curl bar.
    case ezCurl
    /// A hex or trap bar for deadlifts and carries.
    case trap
}

/// What someone can actually load: their bars, plates with how many pairs of each, and the
/// steps their dumbbells and machine stacks go up in (#21).
///
/// Weights are stored in kilograms like everything else, but the kit itself is in one unit: a
/// 2.5 lb plate is 2.5 lb, not 1.134 kg. `system` is that unit, and the calculator works in it
/// so pound plates add up exactly. It doesn't follow the display unit, since someone who reads
/// pounds can still train with kilo plates.
public struct PlateInventory: Codable, Hashable, Sendable {
    public struct Bar: Codable, Hashable, Sendable, Identifiable {
        public var kind: BarKind
        public var kg: Double

        public var id: BarKind { kind }

        public init(_ kind: BarKind, kg: Double) {
            self.kind = kind
            self.kg = kg
        }
    }

    public struct Plate: Codable, Hashable, Sendable {
        /// One plate's weight.
        public var kg: Double
        /// How many pairs there are; plates go on in pairs, one each side.
        public var pairs: Int

        public init(kg: Double, pairs: Int) {
            self.kg = kg
            self.pairs = pairs
        }
    }

    /// The unit the kit is marked in.
    public var system: UnitSystem
    /// One of each kind of bar, with its weight.
    public var bars: [Bar]
    /// The bar barbell work is loaded on.
    public var barKind: BarKind
    public var plates: [Plate]
    /// Dumbbells go up in this step, from one step to `heaviestDumbbellKg`.
    public var dumbbellStepKg: Double
    public var heaviestDumbbellKg: Double
    /// The step between pins on a machine or cable stack.
    public var machineStepKg: Double

    public init(
        system: UnitSystem, bars: [Bar], barKind: BarKind = .standard, plates: [Plate], dumbbellStepKg: Double,
        heaviestDumbbellKg: Double, machineStepKg: Double
    ) {
        self.system = system
        self.bars = bars
        self.barKind = barKind
        self.plates = plates
        self.dumbbellStepKg = dumbbellStepKg
        self.heaviestDumbbellKg = heaviestDumbbellKg
        self.machineStepKg = machineStepKg
    }

    // MARK: Bars

    /// The chosen bar. A kind missing from `bars` falls back to a standard bar in this unit.
    public var bar: Bar {
        bar(barKind)
    }

    public var barKg: Double {
        bar.kg
    }

    /// The bar of a kind, or its usual weight in this unit if it hasn't been set up.
    public func bar(_ kind: BarKind) -> Bar {
        bars.first { $0.kind == kind } ?? Self.defaultBars(system).first { $0.kind == kind } ?? Bar(kind, kg: 20)
    }

    /// Sets the chosen bar's weight, adding the bar if it wasn't listed.
    public mutating func setBarKg(_ kg: Double) {
        if let index = bars.firstIndex(where: { $0.kind == barKind }) {
            bars[index].kg = kg
        } else {
            bars.append(Bar(barKind, kg: kg))
        }
    }

    // MARK: Units

    /// A weight in this kit's unit, e.g. 20.41 kg → 45 lb.
    public func display(kg: Double) -> Double {
        Double(hundredths(kg: kg)) / 100
    }

    /// A weight in this kit's unit, converted to kilograms.
    public func kilograms(fromDisplay value: Double) -> Double {
        system == .metric ? value : value / Units.poundsPerKilogram
    }

    /// The weight in hundredths of this kit's unit. Every real plate is a whole number of these,
    /// so sums are exact integers, and rounding here absorbs the float error of the kg round trip.
    func hundredths(kg: Double) -> Int {
        let value = system == .metric ? kg : kg * Units.poundsPerKilogram
        return Int((value * 100).rounded())
    }

    func kilograms(hundredths: Int) -> Double {
        kilograms(fromDisplay: Double(hundredths) / 100)
    }
}

// MARK: Presets

extension PlateInventory {
    /// Quick starts for the equipment setup.
    public enum Preset: String, CaseIterable, Sendable {
        /// A full commercial gym: plenty of every plate, dumbbells to 50 kg or 120 lb.
        case commercialGym
        /// A home rack: a bar, a modest set of plates and adjustable dumbbells.
        case home
    }

    /// A preset in kilograms or pounds.
    public init(_ preset: Preset, system: UnitSystem) {
        // Plates as (weight, pairs) in the unit, heaviest first.
        let plates: [(Double, Int)]
        let dumbbells: (step: Double, heaviest: Double)
        let machine: Double
        switch (preset, system) {
        case (.commercialGym, .metric):
            plates = [(25, 4), (20, 2), (15, 2), (10, 3), (5, 3), (2.5, 3), (1.25, 2)]
            dumbbells = (2.5, 50)
            machine = 5
        case (.commercialGym, .imperial):
            plates = [(45, 6), (35, 2), (25, 3), (10, 3), (5, 3), (2.5, 3)]
            dumbbells = (5, 120)
            machine = 10
        case (.home, .metric):
            plates = [(20, 1), (10, 2), (5, 2), (2.5, 2), (1.25, 1)]
            dumbbells = (2, 24)
            machine = 2.5
        case (.home, .imperial):
            plates = [(45, 2), (25, 2), (10, 2), (5, 2), (2.5, 1)]
            dumbbells = (5, 50)
            machine = 5
        }
        let kg = { (value: Double) in system == .metric ? value : value / Units.poundsPerKilogram }
        self.init(
            system: system, bars: Self.defaultBars(system),
            plates: plates.map { Plate(kg: kg($0.0), pairs: $0.1) },
            dumbbellStepKg: kg(dumbbells.step), heaviestDumbbellKg: kg(dumbbells.heaviest),
            machineStepKg: kg(machine))
    }

    /// The commercial-gym preset in the locale's unit, which new profiles start with.
    public static func standard(for locale: Locale = .current) -> PlateInventory {
        PlateInventory(.commercialGym, system: .preferred(for: locale))
    }

    /// The preset this inventory matches exactly, whichever bar is chosen, if any.
    public var preset: Preset? {
        Preset.allCases.first { preset in
            var candidate = PlateInventory(preset, system: system)
            candidate.barKind = barKind
            return candidate == self
        }
    }

    /// The usual bar weights: 20, 15, 10 and 25 kg, or 45, 35, 25 and 55 lb.
    static func defaultBars(_ system: UnitSystem) -> [Bar] {
        let weights: [(BarKind, Double)] =
            system == .metric
            ? [(.standard, 20), (.light, 15), (.ezCurl, 10), (.trap, 25)]
            : [(.standard, 45), (.light, 35), (.ezCurl, 25), (.trap, 55)]
        return weights.map { Bar($0.0, kg: system == .metric ? $0.1 : $0.1 / Units.poundsPerKilogram) }
    }
}
