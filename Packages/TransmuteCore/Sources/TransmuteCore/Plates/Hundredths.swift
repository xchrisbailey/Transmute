import Foundation

/// A weight as a whole number of hundredths of a kit's unit, so sums are exact integers and
/// the rounding on the way in absorbs the float error of the kg round trip.
struct Hundredths: Hashable, Comparable, AdditiveArithmetic, Sendable {
    let count: Int

    static let zero = Hundredths(count: 0)

    private init(count: Int) {
        self.count = count
    }

    init(kg: Double, in system: UnitSystem) {
        let value = system.display(kilograms: kg)
        self.init(count: Int((value * 100).rounded()))
    }

    func kg(in system: UnitSystem) -> Double {
        let value = Double(count) / 100
        return system.kilograms(fromDisplay: value)
    }

    /// The weight in the kit's unit, e.g. 2.5 for a 2.5 lb plate in a pound kit.
    var inUnit: Double {
        Double(count) / 100
    }

    /// Half, or `nil` when the count is odd and there is no whole half.
    var half: Hundredths? {
        count.isMultiple(of: 2) ? Hundredths(count: count / 2) : nil
    }

    static func < (lhs: Hundredths, rhs: Hundredths) -> Bool {
        lhs.count < rhs.count
    }

    static func + (lhs: Hundredths, rhs: Hundredths) -> Hundredths {
        Hundredths(count: lhs.count + rhs.count)
    }

    static func - (lhs: Hundredths, rhs: Hundredths) -> Hundredths {
        Hundredths(count: lhs.count - rhs.count)
    }

    static func * (times: Int, weight: Hundredths) -> Hundredths {
        Hundredths(count: times * weight.count)
    }

    static func / (dividend: Hundredths, divisor: Hundredths) -> Int {
        dividend.count / divisor.count
    }
}
