#if !os(watchOS)
    import SwiftUI
    import TransmuteCore

    /// What to put on the bar for a target weight (#21): a drawn bar with each side's plates,
    /// labelled, and the nearest loadable weights when the target can't be made exactly. It
    /// follows the binding, so it updates as the weight changes, and its stepper moves the
    /// weight to the next loadable one either way.
    ///
    ///     .sheet(isPresented: $showsPlates) {
    ///         PlateSheet(targetKg: $set.weightKg, inventory: profile.plates, units: units)
    ///     }
    public struct PlateSheet: View {
        @Binding var targetKg: Double
        let inventory: PlateInventory
        let units: Units
        let barKind: BarKind?
        @Environment(\.dismiss) private var dismiss

        /// - Parameter bar: The bar to load, e.g. `.trap` for a trap-bar deadlift; the
        ///   inventory's chosen bar when `nil`.
        public init(targetKg: Binding<Double>, inventory: PlateInventory, units: Units, bar: BarKind? = nil) {
            _targetKg = targetKg
            self.inventory = inventory
            self.units = units
            self.barKind = bar
        }

        public var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        weightStepper
                        if let exact = solution.exact {
                            loaded(exact)
                        } else {
                            choices
                        }
                    }
                    .padding()
                }
                .background(Color.brand(\.base))
                .navigationTitle(Text(PlateCopy.plates))
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Text(PlateCopy.done)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }

        private var calculator: PlateCalculator {
            PlateCalculator(inventory: inventory, bar: barKind)
        }

        private var solution: PlateSolution {
            calculator.solve(kg: targetKg)
        }

        private var weightStepper: some View {
            Stepper {
                Text(verbatim: units.formatWeight(kg: targetKg))
                    .brandNumberFont(size: 34, relativeTo: .largeTitle)
                    .foregroundStyle(Color.brand(\.ink))
            } onIncrement: {
                if let above = solution.above { targetKg = above.totalKg }
            } onDecrement: {
                if let below = solution.below { targetKg = below.totalKg }
            }
            .accessibilityLabel(Text(PlateCopy.weight))
            .accessibilityValue(Text(verbatim: units.formatWeight(kg: targetKg)))
        }

        private func loaded(_ loading: PlateLoading) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(PlateCopy.perSide(units(for: loading).weightSymbol))
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
                BarDrawing(loading: loading)
                if loading.isBarOnly {
                    Text(PlateCopy.justTheBar)
                        .brandFont(.exerciseTitle)
                } else {
                    Text(verbatim: PlateText.plates(loading, locale: units.locale))
                        .brandNumberFont(size: 22, relativeTo: .title2)
                        .foregroundStyle(Color.brand(\.ink))
                        .accessibilityHidden(true)
                }
                Text(PlateCopy.onBar(units.formatWeight(kg: loading.bar.kg)))
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
        }

        private var choices: some View {
            VStack(alignment: .leading, spacing: 12) {
                if solution.below == nil {
                    Text(PlateCopy.lighterThanBar(units.formatWeight(kg: calculator.bar.kg)))
                } else if solution.above == nil {
                    Text(PlateCopy.moreThanPlates)
                } else {
                    Text(PlateCopy.cantLoad(units.formatWeight(kg: targetKg)))
                }
                if let below = solution.below {
                    choice(PlateCopy.lighter(units.formatWeight(kg: below.totalKg), plates: summary(below)), below)
                }
                if let above = solution.above {
                    choice(PlateCopy.heavier(units.formatWeight(kg: above.totalKg), plates: summary(above)), above)
                }
            }
            .brandFont(.body)
        }

        private func choice(_ label: LocalizedStringResource, _ loading: PlateLoading) -> some View {
            Button {
                targetKg = loading.totalKg
            } label: {
                Text(label)
                    .brandFont(.body)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.brand(\.surface0), in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.brand(\.ink))
        }

        /// The plates in words, or "just the bar".
        private func summary(_ loading: PlateLoading) -> String {
            PlateText.compact(loading, locale: units.locale)
        }

        /// Plate labels are in the kit's unit, which may not be the display unit.
        private func units(for loading: PlateLoading) -> Units {
            Units(system: loading.system, locale: units.locale)
        }
    }

    /// One side of a loaded bar: the shaft, the collar, then the plates from heaviest out, each
    /// labelled with its weight. Taller plates are heavier, and the labels carry the numbers,
    /// so the colours are never the only cue.
    struct BarDrawing: View {
        let loading: PlateLoading
        @Environment(\.locale) private var locale
        @ScaledMetric(relativeTo: .caption) private var labelSize = 12

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 2) {
                    Rectangle()
                        .fill(Color.brand(\.overlay1))
                        .frame(width: 28, height: 8)
                    Rectangle()
                        .fill(Color.brand(\.overlay1))
                        .frame(width: 8, height: 30)
                    ForEach(Array(loading.perSide.enumerated()), id: \.offset) { _, plate in
                        plateView(plate)
                    }
                    Rectangle()
                        .fill(Color.brand(\.overlay1))
                        .frame(width: 24, height: 8)
                }
                .padding(.vertical, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(description))
        }

        private func plateView(_ plate: Double) -> some View {
            VStack(spacing: 4) {
                Color.clear.frame(height: labelSize * 1.4)
                RoundedRectangle(cornerRadius: 4)
                    .fill(PlateStyle.color(kg: kg(plate)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4).strokeBorder(Color.brand(\.crust), lineWidth: 1)
                    }
                    .frame(width: 22, height: PlateStyle.height(kg: kg(plate)))
                Text(verbatim: PlateText.weight(plate, locale: locale))
                    .font(.brandNumber(size: labelSize, relativeTo: .caption))
                    .foregroundStyle(Color.brand(\.ink))
                    .fixedSize()
                    .frame(height: labelSize * 1.4)
            }
            .frame(minWidth: 30)
        }

        private func kg(_ plate: Double) -> Double {
            loading.system == .metric ? plate : plate / Units.poundsPerKilogram
        }

        private var description: LocalizedStringResource {
            let units = Units(system: loading.system, locale: locale)
            let bar = units.formatWeight(kg: loading.bar.kg)
            guard !loading.isBarOnly else { return PlateCopy.describeBarOnly(bar) }
            var plates = loading.perSide.map { PlateText.weight($0, locale: locale) }
            plates[plates.count - 1] += " \(units.weightSymbol)"
            return PlateCopy.describe(plates.formatted(.list(type: .and).locale(locale)), bar: bar)
        }
    }

    /// How plates are drawn. Colours loosely follow the competition code (red 25, blue 20,
    /// green 10, light change plates) using brand roles; gold is kept for records, so 15s are
    /// pink rather than yellow.
    enum PlateStyle {
        static func color(kg: Double) -> Color {
            switch kg {
            case 22...: Color.brand(\.alert)
            case 18..<22: Color.brand(\.sparkleLavender)
            case 13..<18: Color.brand(\.sparklePink)
            case 8..<13: Color.brand(\.done)
            case 4..<8: Color.brand(\.subtext)
            default: Color.brand(\.overlay0)
            }
        }

        /// From 36pt for the smallest change plate to 120pt for a 25.
        static func height(kg: Double) -> CGFloat {
            36 + 84 * min(1, (max(kg, 0) / 25).squareRoot())
        }
    }

    #Preview {
        @Previewable @State var kg = 101.0
        Text(verbatim: "Set").sheet(isPresented: .constant(true)) {
            PlateSheet(
                targetKg: $kg, inventory: PlateInventory(.commercialGym, system: .metric), units: Units(system: .metric)
            )
        }
    }
#endif
