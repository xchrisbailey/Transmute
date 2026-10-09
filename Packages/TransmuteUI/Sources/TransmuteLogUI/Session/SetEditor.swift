import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Steppers and fields for one set, sized for a thumb and big text (#22).
struct SetEditor: View {
    @Bindable var set: LoggedSet
    let tracking: TrackingType
    let equipment: Set<Equipment>
    let units: Units
    let plates: PlateInventory?
    /// Offers the countdown for timed sets and intervals; off when editing past sets.
    var timers = true
    let onDone: () -> Void

    @Environment(\.effortDisplay) private var effort
    @State private var showsPlates = false

    var body: some View {
        VStack(spacing: 10) {
            switch tracking {
            case .weightReps:
                weightField
                if let plates, let kg = set.weightKg {
                    platesButton(plates, kg: kg)
                }
                intField(LogCopy.reps, value: $set.reps, step: 1, range: 0...100)
            case .reps:
                intField(LogCopy.reps, value: $set.reps, step: 1, range: 0...500)
            case .time:
                secondsField(LogCopy.seconds, value: $set.seconds)
                if timers {
                    TimedSet(set: set, rounds: 1, work: set.seconds ?? 30, rest: 0, onDone: onDone)
                }
            case .distanceTime:
                doubleField(LogCopy.meters, value: $set.meters, step: 5, range: 0...100_000)
                secondsField(LogCopy.seconds, value: $set.seconds)
            case .intervals:
                intField(LogCopy.rounds, value: $set.rounds, step: 1, range: 1...50)
                secondsField(LogCopy.seconds, value: $set.seconds)
                if timers {
                    TimedSet(
                        set: set, rounds: set.rounds ?? 1, work: set.seconds ?? 20,
                        rest: set.intervalRestSeconds ?? 0, onDone: onDone)
                }
            }
            if effort.showsRPE, tracking == .weightReps || tracking == .reps {
                rpeField
            }
        }
    }

    /// Steps by the smallest jump this kit allows, in the user's unit.
    private var weightField: some View {
        let step = LoadableWeight.step(for: equipment, system: units.weight)
        return NumberStepper(
            label: Text(LogCopy.weight), unit: units.weightSymbol,
            value: Binding(
                get: { set.weightKg.map { (units.displayWeight(kg: $0) * 2).rounded() / 2 } },
                set: { set.weightKg = $0.map(units.kilograms(fromDisplay:)) }),
            step: units.displayWeight(kg: step).rounded(toPlaces: 2), range: 0...1_000)
    }

    /// "per side: 20 · 10 · 2.5", opening the drawn bar to change the weight.
    private func platesButton(_ plates: PlateInventory, kg: Double) -> some View {
        let bar: BarKind? = equipment.contains(.trapBar) && !equipment.contains(.barbell) ? .trap : nil
        let loading = PlateCalculator(inventory: plates, bar: bar).solve(kg: kg).nearest
        return Button {
            showsPlates = true
        } label: {
            Label {
                Text(verbatim: loading.map { PlateText.compact($0) } ?? String(localized: LogCopy.plates))
                    .brandNumberFont(size: 15)
            } icon: {
                Image(systemName: "circle.grid.2x1")
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .accessibilityHint(Text(LogCopy.plates))
        .sheet(isPresented: $showsPlates) {
            PlateSheet(
                targetKg: Binding(get: { set.weightKg ?? kg }, set: { set.weightKg = $0 }), inventory: plates,
                units: units, bar: bar)
        }
    }

    private var rpeField: some View {
        NumberStepper(label: Text(LogCopy.rpe), unit: nil, value: $set.rpe, step: 0.5, range: 1...10)
    }

    private func intField(
        _ label: LocalizedStringResource, value: Binding<Int?>, step: Int, range: ClosedRange<Int>
    ) -> some View {
        NumberStepper(
            label: Text(label), unit: nil,
            value: Binding(
                get: { value.wrappedValue.map(Double.init) }, set: { value.wrappedValue = $0.map(Int.init) }),
            step: Double(step), range: Double(range.lowerBound)...Double(range.upperBound), fractionDigits: 0)
    }

    private func doubleField(
        _ label: LocalizedStringResource, value: Binding<Double?>, step: Double, range: ClosedRange<Double>
    ) -> some View {
        NumberStepper(label: Text(label), unit: nil, value: value, step: step, range: range, fractionDigits: 0)
    }

    private func secondsField(_ label: LocalizedStringResource, value: Binding<Double?>) -> some View {
        NumberStepper(label: Text(label), unit: nil, value: value, step: 5, range: 0...7_200, fractionDigits: 0)
    }
}
