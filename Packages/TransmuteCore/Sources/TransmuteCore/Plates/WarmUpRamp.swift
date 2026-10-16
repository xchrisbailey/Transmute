import Foundation

public struct WarmUpSet: Hashable, Sendable {
    public let reps: Int
    public let loading: PlateLoading
}

extension PlateCalculator {
    /// The usual ramp: the empty bar for 10, then about 40%, 60% and 80% of the working weight
    /// for 5, 3 and 2. Each step rounds down to what loads, so warm-ups never come out heavy,
    /// and steps that land on the same weight, or on the working weight, are dropped.
    ///
    /// Empty when the working weight is the bar or lighter.
    public func warmUps(to workingKg: Double) -> [WarmUpSet] {
        let working = Hundredths(kg: workingKg, in: inventory.system)
        let barOnly = solve(kg: bar.kg).exact
        guard let barOnly, working > Hundredths(kg: bar.kg, in: inventory.system) else { return [] }
        var sets = [WarmUpSet(reps: 10, loading: barOnly)]
        for (fraction, reps) in [(0.4, 5), (0.6, 3), (0.8, 2)] {
            let solution = solve(kg: workingKg * fraction)
            guard let loading = solution.exact ?? solution.below,
                let previous = sets.last?.loading.total,
                loading.total > previous,
                Hundredths(kg: loading.totalKg, in: inventory.system) < working
            else { continue }
            sets.append(WarmUpSet(reps: reps, loading: loading))
        }
        return sets
    }
}
