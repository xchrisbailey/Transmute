import Foundation

/// A number on the watch's set screen that the Digital Crown turns (#15).
public enum SetField: String, Sendable, CaseIterable {
    case weight, reps, seconds, meters
}

/// Turns a set's values one step at a time, in the units the person sees. The watch shows the
/// first field as its one big number and the second, if there is one, in peach beside it.
public struct SetDial: Sendable {
    public let tracking: TrackingType
    public let equipment: Set<Equipment>
    public let units: Units

    public init(tracking: TrackingType, equipment: Set<Equipment> = [], units: Units) {
        self.tracking = tracking
        self.equipment = equipment
        self.units = units
    }

    /// The fields this kind of exercise is logged with, the big one first.
    public var fields: [SetField] {
        switch tracking {
        case .weightReps: [.weight, .reps]
        case .reps: [.reps]
        case .time, .intervals: [.seconds]
        case .distanceTime: [.meters, .seconds]
        }
    }

    /// One click of the crown, in the unit shown: the smallest loadable jump for weight, one
    /// rep, five seconds, and a distance step that grows with the distance.
    public func step(for field: SetField, in values: SetValues) -> Double {
        switch field {
        case .weight:
            units.system == .metric ? LoadableWeight.step(for: equipment, system: .metric) : 5
        case .reps:
            1
        case .seconds:
            5
        case .meters:
            switch values.meters ?? 0 {
            case 1_000...: 100
            case 100...: 10
            default: 5
            }
        }
    }

    public func range(for field: SetField) -> ClosedRange<Double> {
        switch field {
        case .weight: 0...units.displayWeight(kg: 500).rounded()
        case .reps: 0...100
        case .seconds: 0...3_600
        case .meters: 0...42_000
        }
    }

    /// The field's value as shown: weight in the person's unit, everything else as stored.
    public func value(of field: SetField, in values: SetValues) -> Double {
        switch field {
        case .weight: values.weightKg.map(units.displayWeight(kg:)) ?? 0
        case .reps: Double(values.reps ?? 0)
        case .seconds: values.seconds ?? 0
        case .meters: values.meters ?? 0
        }
    }

    /// The values with one field set from the crown, snapped to a whole number of steps and
    /// kept in range.
    public func setting(_ field: SetField, to shown: Double, in values: SetValues) -> SetValues {
        let step = step(for: field, in: values)
        let range = range(for: field)
        let snapped = min(max((shown / step).rounded() * step, range.lowerBound), range.upperBound)
        var values = values
        switch field {
        case .weight: values.weightKg = units.kilograms(fromDisplay: snapped)
        case .reps: values.reps = Int(snapped)
        case .seconds: values.seconds = snapped
        case .meters: values.meters = snapped
        }
        return values
    }

    /// The values moved by a number of crown clicks, for VoiceOver's adjust gesture.
    public func adjusting(_ field: SetField, by clicks: Int, in values: SetValues) -> SetValues {
        let shown = value(of: field, in: values) + Double(clicks) * step(for: field, in: values)
        return setting(field, to: shown, in: values)
    }

    /// The number alone, e.g. "102.5", "5", "0:45" or "400 m". An empty field shows a dash.
    public func text(for field: SetField, in values: SetValues) -> String {
        switch field {
        case .weight:
            guard let kg = values.weightKg else { return "–" }
            let shown = (units.displayWeight(kg: kg) * 2).rounded() / 2
            return shown.formatted(.number.precision(.fractionLength(0...1)).locale(units.locale))
        case .reps:
            return values.reps.map(String.init) ?? "–"
        case .seconds:
            return values.seconds.map { Units.clock(seconds: $0) } ?? "–"
        case .meters:
            return values.meters.map { units.formatDistance(meters: $0) } ?? "–"
        }
    }
}
