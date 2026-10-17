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
/// steps their dumbbells and machine stacks go up in.
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

    public struct Plate: Codable, Hashable, Sendable, Identifiable {
        public var kg: Double
        /// How many pairs there are; plates go on in pairs, one each side.
        public var pairs: Int

        /// A kit holds one entry per weight, so the weight tells plates apart.
        public var id: Double { kg }

        public init(kg: Double, pairs: Int) {
            self.kg = kg
            self.pairs = pairs
        }

        /// A row with no count in a backup holds no pairs: the kit doesn't claim plates it can't
        /// show were owned. The weight has no default. This serves backups only; encoding is
        /// synthesized and writes every member.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            kg = try container.decode(Double.self, forKey: .kg)
            pairs = try container.decodeIfPresent(Int.self, forKey: .pairs) ?? 0
        }
    }

    /// The unit the kit is marked in.
    public var system: UnitSystem
    /// One of each kind of bar, with its weight.
    public var bars: [Bar]
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

    /// A member missing from a backup keeps the commercial-gym preset's value in the kit's unit,
    /// like the restore's repair of a value that can't be real. The unit has no default (it isn't
    /// the locale's to guess), and neither has a bar's weight: `Bar` can't know the unit it's in,
    /// and SwiftData decodes `bars` through `Bar` itself, so the lenience can't live out here. This
    /// serves backups only; encoding is synthesized and writes every member.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        system = try container.decode(UnitSystem.self, forKey: .system)
        let defaults = Self(.commercialGym, system: system)
        bars = try container.decodeIfPresent([Bar].self, forKey: .bars) ?? defaults.bars
        barKind = try container.decodeIfPresent(BarKind.self, forKey: .barKind) ?? defaults.barKind
        plates = try container.decodeIfPresent([Plate].self, forKey: .plates) ?? defaults.plates
        dumbbellStepKg =
            try container.decodeIfPresent(Double.self, forKey: .dumbbellStepKg) ?? defaults.dumbbellStepKg
        heaviestDumbbellKg =
            try container.decodeIfPresent(Double.self, forKey: .heaviestDumbbellKg) ?? defaults.heaviestDumbbellKg
        machineStepKg = try container.decodeIfPresent(Double.self, forKey: .machineStepKg) ?? defaults.machineStepKg
    }

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

    /// A weight in this kit's unit, e.g. 20.41 kg → 45 lb.
    public func display(kg: Double) -> Double {
        Hundredths(kg: kg, in: system).inUnit
    }

    /// A weight in this kit's unit, converted to kilograms.
    public func kilograms(fromDisplay value: Double) -> Double {
        system.kilograms(fromDisplay: value)
    }
}

extension PlateInventory {
    public enum Preset: String, CaseIterable, Sendable {
        /// A full commercial gym: plenty of every plate, dumbbells to 50 kg or 120 lb.
        case commercialGym
        /// A home rack: a bar, a modest set of plates and adjustable dumbbells.
        case home
    }

    public init(_ preset: Preset, system: UnitSystem) {
        let plates: [(weight: Double, pairs: Int)]
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
        self.init(
            system: system, bars: Self.defaultBars(system),
            plates: plates.map { Plate(kg: system.kilograms(fromDisplay: $0.weight), pairs: $0.pairs) },
            dumbbellStepKg: system.kilograms(fromDisplay: dumbbells.step),
            heaviestDumbbellKg: system.kilograms(fromDisplay: dumbbells.heaviest),
            machineStepKg: system.kilograms(fromDisplay: machine))
    }

    /// Most weight a kit may give a bar, plate or step, on the setup screen and in a restore. Far
    /// past any gym, far short of where `Hundredths` stops holding a weight.
    public static let heaviestPlausibleKg = 100_000.0
    /// Most pairs of one plate the setup screen offers, on its stepper and its add button.
    public static let mostPairsPerPlate = 20
    /// Most plate rows a kit may hold, on the setup screen and in a restore. A real kit has about
    /// ten to fifteen.
    public static let mostPlateRows = 40

    /// Whether the setup screen takes a bar, plate or step of this weight: above zero and no more
    /// than `heaviestPlausibleKg`, which is what a restore keeps.
    public static func accepts(kg: Double) -> Bool {
        kg > 0 && kg <= heaviestPlausibleKg
    }

    /// Adds one pair of a plate from the setup screen's add button: a new row for a weight the kit
    /// doesn't hold, or one more pair on its row, up to `mostPairsPerPlate` like the stepper. Past
    /// `mostPlateRows` rows a new weight adds nothing.
    public mutating func addPair(ofKg kg: Double) {
        if let index = plates.firstIndex(where: { display(kg: $0.kg) == display(kg: kg) }) {
            if plates[index].pairs < Self.mostPairsPerPlate { plates[index].pairs += 1 }
        } else if plates.count < Self.mostPlateRows {
            plates.append(.init(kg: kg, pairs: 1))
            plates.sort { $0.kg > $1.kg }
        }
    }

    /// This kit as a restore may apply it, and whether anything in it couldn't be real. A backup is
    /// a file anyone can edit, and the plate maths traps on a weight `Hundredths` can't hold, so the
    /// restore repairs only what can't be real and keeps the rest as written:
    /// - a plate row whose weight is not a finite number above zero and within
    ///   `heaviestPlausibleKg` is dropped;
    /// - a bar weight or a dumbbell or machine step outside `0...heaviestPlausibleKg` goes back to the
    ///   commercial-gym preset's value for that field, in this kit's unit;
    /// - a negative pair count becomes zero, and a count over `mostPairsPerPlate` is capped there.
    ///   Kits past the cap were written before the add button respected it, so capping is not a
    ///   repair worth reporting;
    /// - rows of one weight merge, their pairs capped at `mostPairsPerPlate` again;
    /// - rows past `mostPlateRows` are dropped, the first ones kept. The plate maths grows steeply
    ///   with the number of distinct weights. The setup screen stops at the cap too, but a kit
    ///   written before it did, or an edited file, can hold more.
    /// Zero pairs is fine: the setup screen can leave a row at none.
    func repairedForRestore() -> (kit: PlateInventory, repaired: Bool) {
        let preset = PlateInventory(.commercialGym, system: system)
        var kit = self
        var repaired = false
        func plausible(_ kg: Double) -> Bool { kg >= 0 && kg <= Self.heaviestPlausibleKg }
        func resetting(_ kg: Double, to presetKg: Double) -> Double {
            if plausible(kg) { return kg }
            repaired = true
            return presetKg
        }
        kit.bars = bars.map { bar in
            Bar(bar.kind, kg: resetting(bar.kg, to: preset.bar(bar.kind).kg))
        }
        kit.dumbbellStepKg = resetting(dumbbellStepKg, to: preset.dumbbellStepKg)
        kit.heaviestDumbbellKg = resetting(heaviestDumbbellKg, to: preset.heaviestDumbbellKg)
        kit.machineStepKg = resetting(machineStepKg, to: preset.machineStepKg)
        kit.plates = []
        for plate in plates {
            guard plate.kg > 0, plausible(plate.kg) else {
                repaired = true
                continue
            }
            if plate.pairs < 0 { repaired = true }
            let pairs = min(max(plate.pairs, 0), Self.mostPairsPerPlate)
            if let index = kit.plates.firstIndex(where: { sameWeight($0.kg, plate.kg) }) {
                kit.plates[index].pairs = min(kit.plates[index].pairs + pairs, Self.mostPairsPerPlate)
            } else {
                kit.plates.append(.init(kg: plate.kg, pairs: pairs))
            }
        }
        if kit.plates.count > Self.mostPlateRows {
            kit.plates.removeLast(kit.plates.count - Self.mostPlateRows)
            repaired = true
        }
        return (kit, repaired)
    }

    private func sameWeight(_ lhs: Double, _ rhs: Double) -> Bool {
        Hundredths(kg: lhs, in: system) == Hundredths(kg: rhs, in: system)
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
        return weights.map { Bar($0.0, kg: system.kilograms(fromDisplay: $0.1)) }
    }
}
