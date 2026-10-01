#if !os(watchOS)
    import SwiftUI
    import TransmuteCore

    /// Bars, plates and the dumbbell and machine steps (#21). Edits a binding, so it works on a
    /// `ProfileDraft` and is saved with the rest of the profile.
    ///
    /// Weights here are in the kit's own unit, which can differ from the display unit: plates
    /// are marked in one or the other.
    public struct PlateSetupView: View {
        @Binding var inventory: PlateInventory
        @State private var newPlate: Double?

        public init(inventory: Binding<PlateInventory>) {
            _inventory = inventory
        }

        public var body: some View {
            Form {
                Section {
                    Picker(selection: preset) {
                        ForEach(PlateInventory.Preset.allCases, id: \.self) { preset in
                            Text(preset.label).tag(PlateInventory.Preset?.some(preset))
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Picker(selection: system) {
                        Text(PlateCopy.kilograms).tag(UnitSystem.metric)
                        Text(PlateCopy.pounds).tag(UnitSystem.imperial)
                    } label: {
                        Text(PlateCopy.markedIn)
                    }
                } header: {
                    Text(PlateCopy.presets)
                } footer: {
                    Text(PlateCopy.unitNote)
                }
                Section {
                    Picker(selection: $inventory.barKind) {
                        ForEach(BarKind.allCases, id: \.self) { kind in
                            Text(kind.label).tag(kind)
                        }
                    } label: {
                        Text(PlateCopy.bar)
                    }
                    KitWeightField(
                        label: PlateCopy.barWeight, value: kit(\.barKg, set: { $0.setBarKg($1) }), units: units)
                } header: {
                    Text(PlateCopy.bar)
                }
                Section {
                    ForEach(inventory.plates.indices, id: \.self) { index in
                        plateRow(index)
                    }
                    .onDelete { inventory.plates.remove(atOffsets: $0) }
                    HStack {
                        KitWeightField(label: PlateCopy.newPlate, value: $newPlate, units: units)
                        Button {
                            addPlate()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .frame(minWidth: 44, minHeight: 44)
                                .accessibilityLabel(Text(PlateCopy.addPlate))
                        }
                        .buttonStyle(.borderless)
                        .disabled((newPlate ?? 0) <= 0)
                    }
                } header: {
                    Text(PlateCopy.plates)
                } footer: {
                    Text(PlateCopy.platesNote)
                }
                Section {
                    KitWeightField(
                        label: PlateCopy.dumbbellStep,
                        value: kit(\.dumbbellStepKg, set: { $0.dumbbellStepKg = $1 }), units: units)
                    KitWeightField(
                        label: PlateCopy.heaviestDumbbell,
                        value: kit(\.heaviestDumbbellKg, set: { $0.heaviestDumbbellKg = $1 }), units: units)
                    KitWeightField(
                        label: PlateCopy.machineStep,
                        value: kit(\.machineStepKg, set: { $0.machineStepKg = $1 }), units: units)
                } header: {
                    Text(PlateCopy.steps)
                } footer: {
                    Text(PlateCopy.stepsNote)
                }
            }
            .navigationTitle(Text(PlateCopy.setup))
        }

        private var units: Units {
            Units(system: inventory.system)
        }

        private func plateRow(_ index: Int) -> some View {
            let plate = inventory.plates[index]
            let weight = "\(PlateText.weight(inventory.display(kg: plate.kg))) \(units.weightSymbol)"
            return Stepper(value: pairs(index), in: 0...20) {
                HStack {
                    Circle()
                        .fill(PlateStyle.color(kg: plate.kg))
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                    Text(verbatim: weight)
                        .brandNumberFont(size: 17)
                    Spacer()
                    Text(PlateCopy.pairs(plate.pairs))
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(PlateCopy.plateRow(weight, pairs: plate.pairs)))
        }

        /// A plate's pair count, safe against the row outliving a delete.
        private func pairs(_ index: Int) -> Binding<Int> {
            Binding {
                inventory.plates.indices.contains(index) ? inventory.plates[index].pairs : 0
            } set: { pairs in
                if inventory.plates.indices.contains(index) { inventory.plates[index].pairs = pairs }
            }
        }

        private func addPlate() {
            guard let kg = newPlate, kg > 0 else { return }
            if let index = inventory.plates.firstIndex(where: {
                inventory.display(kg: $0.kg) == inventory.display(kg: kg)
            }) {
                inventory.plates[index].pairs += 1
            } else {
                inventory.plates.append(.init(kg: kg, pairs: 1))
                inventory.plates.sort { $0.kg > $1.kg }
            }
            newPlate = nil
        }

        /// Picking a preset keeps the chosen bar.
        private var preset: Binding<PlateInventory.Preset?> {
            Binding {
                inventory.preset
            } set: { preset in
                guard let preset else { return }
                let bar = inventory.barKind
                inventory = PlateInventory(preset, system: inventory.system)
                inventory.barKind = bar
            }
        }

        /// Plates in the other unit are different plates, so switching starts from that unit's
        /// preset.
        private var system: Binding<UnitSystem> {
            Binding {
                inventory.system
            } set: { system in
                guard system != inventory.system else { return }
                let bar = inventory.barKind
                inventory = PlateInventory(inventory.preset ?? .commercialGym, system: system)
                inventory.barKind = bar
            }
        }

        private func kit(
            _ get: KeyPath<PlateInventory, Double>, set: @escaping (inout PlateInventory, Double) -> Void
        ) -> Binding<Double?> {
            Binding {
                inventory[keyPath: get]
            } set: { value in
                if let value, value > 0 { set(&inventory, value) }
            }
        }
    }

    /// A weight in the kit's unit, to two decimals so 1.25 kg change plates fit.
    private struct KitWeightField: View {
        let label: LocalizedStringResource
        @Binding var value: Double?
        let units: Units

        var body: some View {
            LabeledContent {
                HStack {
                    TextField(value: display, format: .number.precision(.fractionLength(0...2))) {
                        Text(label)
                    }
                    .numericEntry()
                    .multilineTextAlignment(.trailing)
                    .brandNumberFont(size: 17)
                    Text(verbatim: units.weightSymbol)
                        .foregroundStyle(Color.brandText(\.subtext))
                        .accessibilityHidden(true)
                }
            } label: {
                Text(label)
            }
        }

        private var display: Binding<Double?> {
            Binding {
                value.map { (units.displayWeight(kg: $0) * 100).rounded() / 100 }
            } set: { entered in
                value = entered.map(units.kilograms(fromDisplay:))
            }
        }
    }

    #Preview {
        @Previewable @State var inventory = PlateInventory(.home, system: .imperial)
        NavigationStack {
            PlateSetupView(inventory: $inventory)
        }
    }
#endif
