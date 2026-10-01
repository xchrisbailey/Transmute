import Foundation

/// A bar and the plates on each side of it.
public struct PlateLoading: Hashable, Sendable {
    public let system: UnitSystem
    public let bar: PlateInventory.Bar
    /// One side's plates, heaviest first (nearest the collar), in the kit's unit, so a 2.5 lb
    /// plate reads 2.5.
    public let perSide: [Double]
    /// Bar plus both sides, in the kit's unit.
    public let total: Double

    /// Bar plus both sides, in kilograms.
    public var totalKg: Double {
        system == .metric ? total : total / Units.poundsPerKilogram
    }

    /// Nothing on the bar.
    public var isBarOnly: Bool {
        perSide.isEmpty
    }
}

/// What the calculator found for a target: the exact loading, or the nearest either side.
public struct PlateSolution: Hashable, Sendable {
    public let targetKg: Double
    /// `nil` when the target can't be made with this bar and these plates.
    public let exact: PlateLoading?
    /// The heaviest loading under the target. `nil` when the target is lighter than the bar.
    public let below: PlateLoading?
    /// The lightest loading over the target. `nil` when the target is more than the plates make.
    public let above: PlateLoading?

    public var isExact: Bool {
        exact != nil
    }

    /// The exact loading, else the closer of below and above, preferring below on a tie.
    public var nearest: PlateLoading? {
        if let exact { return exact }
        guard let below, let above else { return below ?? above }
        return abs(above.totalKg - targetKg) < abs(targetKg - below.totalKg) ? above : below
    }
}

/// Works out the plates for a barbell weight (#21).
///
/// Fills each side greedily from the heaviest plate down, as anyone loading a bar would,
/// respecting how many pairs there are. When greedy runs out (say 15 + 15 when there's one
/// pair of 25s), it backs off the heavier plates until it fits. When the weight can't be made
/// at all, it gives the nearest loadable weights below and above.
///
/// Everything is worked in hundredths of the kit's unit, as integers, so pound plates add up
/// exactly; kilograms only come in and go out at the edges.
public struct PlateCalculator: Sendable {
    public let inventory: PlateInventory
    public let bar: PlateInventory.Bar
    /// Plate weights in hundredths with their pair counts, heaviest first, duplicates merged.
    private let plates: [(weight: Int, pairs: Int)]
    /// Every per-side total the plates can make, in hundredths, ascending.
    private let reachable: [Int]

    /// - Parameter bar: The bar to load; the inventory's chosen bar when `nil`.
    public init(inventory: PlateInventory, bar: BarKind? = nil) {
        self.inventory = inventory
        self.bar = inventory.bar(bar ?? inventory.barKind)
        var merged: [Int: Int] = [:]
        for plate in inventory.plates where plate.pairs > 0 {
            let weight = inventory.hundredths(kg: plate.kg)
            if weight > 0 { merged[weight, default: 0] += plate.pairs }
        }
        plates = merged.sorted { $0.key > $1.key }.map { (weight: $0.key, pairs: $0.value) }
        var sums: Set<Int> = [0]
        for plate in plates {
            var next = sums
            for count in 1...plate.pairs {
                for sum in sums { next.insert(sum + count * plate.weight) }
            }
            sums = next
        }
        reachable = sums.sorted()
    }

    /// The loading for a target weight in kilograms.
    public func solve(kg targetKg: Double) -> PlateSolution {
        let barWeight = inventory.hundredths(kg: bar.kg)
        let needed = inventory.hundredths(kg: targetKg) - barWeight
        // Both sides carry the same, so the plates make up half of what's needed each.
        let exact = needed >= 0 && needed.isMultiple(of: 2) && contains(needed / 2) ? loading(perSide: needed / 2) : nil
        let below = reachable.last { 2 * $0 < needed }.map(loading(perSide:))
        let above = reachable.first { 2 * $0 > needed }.map(loading(perSide:))
        return PlateSolution(targetKg: targetKg, exact: exact, below: below, above: above)
    }

    /// The nearest loadable weight in kilograms; never less than the bar.
    public func nearestKg(_ targetKg: Double) -> Double {
        solve(kg: targetKg).nearest?.totalKg ?? bar.kg
    }

    /// The heaviest weight the plates make on this bar, in kilograms.
    public var heaviestKg: Double {
        loading(perSide: reachable.last ?? 0).totalKg
    }

    private func contains(_ sum: Int) -> Bool {
        var low = 0
        var high = reachable.count
        while low < high {
            let mid = (low + high) / 2
            if reachable[mid] < sum { low = mid + 1 } else { high = mid }
        }
        return low < reachable.count && reachable[low] == sum
    }

    /// The plates for a per-side total that's known to be reachable.
    private func loading(perSide sum: Int) -> PlateLoading {
        var failed: Set<[Int]> = []
        let counts = fill(sum, from: 0, failed: &failed) ?? []
        var side: [Double] = []
        for (plate, count) in zip(plates, counts) {
            side += Array(repeating: Double(plate.weight) / 100, count: count)
        }
        let barWeight = inventory.hundredths(kg: bar.kg)
        return PlateLoading(
            system: inventory.system, bar: bar, perSide: side, total: Double(barWeight + 2 * sum) / 100)
    }

    /// Greedy from `index` down: as many of each plate as fit, backing off one at a time when
    /// what's left can't be made. Returns a count per plate from `index` on.
    private func fill(_ remaining: Int, from index: Int, failed: inout Set<[Int]>) -> [Int]? {
        if remaining == 0 { return Array(repeating: 0, count: plates.count - index) }
        guard index < plates.count, !failed.contains([index, remaining]) else { return nil }
        let plate = plates[index]
        for count in stride(from: min(plate.pairs, remaining / plate.weight), through: 0, by: -1) {
            if let rest = fill(remaining - count * plate.weight, from: index + 1, failed: &failed) {
                return [count] + rest
            }
        }
        failed.insert([index, remaining])
        return nil
    }
}
