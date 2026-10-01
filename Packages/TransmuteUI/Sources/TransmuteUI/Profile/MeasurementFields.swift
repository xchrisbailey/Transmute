#if !os(watchOS)
    import SwiftUI
    import TransmuteCore

    /// A number typed in the person's unit and stored in metric.
    struct WeightField: View {
        let label: LocalizedStringResource
        @Binding var kg: Double?
        let units: Units

        var body: some View {
            LabeledContent {
                HStack {
                    TextField(value: display, format: .number.precision(.fractionLength(0...1))) {
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
                kg.map { (units.displayWeight(kg: $0) * 10).rounded() / 10 }
            } set: { value in
                kg = value.map(units.kilograms(fromDisplay:))
            }
        }
    }

    /// Height in centimetres, or in feet and inches.
    struct HeightField: View {
        @Binding var cm: Double?
        let system: UnitSystem

        var body: some View {
            LabeledContent {
                switch system {
                case .metric:
                    HStack {
                        TextField(value: $cm, format: .number.precision(.fractionLength(0))) {
                            Text(ProfileCopy.height)
                        }
                        .numericEntry()
                        .multilineTextAlignment(.trailing)
                        .brandNumberFont(size: 17)
                        Text(verbatim: "cm")
                            .foregroundStyle(Color.brandText(\.subtext))
                            .accessibilityHidden(true)
                    }
                case .imperial:
                    HStack {
                        TextField(value: feet, format: .number) {
                            Text(ProfileCopy.feet)
                        }
                        .numericEntry()
                        .multilineTextAlignment(.trailing)
                        .brandNumberFont(size: 17)
                        .accessibilityLabel(Text(ProfileCopy.feet))
                        Text(verbatim: "ft")
                            .foregroundStyle(Color.brandText(\.subtext))
                            .accessibilityHidden(true)
                        TextField(value: inches, format: .number) {
                            Text(ProfileCopy.inches)
                        }
                        .numericEntry()
                        .multilineTextAlignment(.trailing)
                        .brandNumberFont(size: 17)
                        .accessibilityLabel(Text(ProfileCopy.inches))
                        Text(verbatim: "in")
                            .foregroundStyle(Color.brandText(\.subtext))
                            .accessibilityHidden(true)
                    }
                }
            } label: {
                Text(ProfileCopy.height)
            }
        }

        private var feet: Binding<Int?> {
            Binding {
                cm.map { Units.feetAndInches(cm: $0).feet }
            } set: { value in
                guard let value else { return cm = nil }
                let inches = cm.map { Units.feetAndInches(cm: $0).inches } ?? 0
                cm = Units.centimetres(feet: value, inches: Double(inches))
            }
        }

        private var inches: Binding<Int?> {
            Binding {
                cm.map { Units.feetAndInches(cm: $0).inches }
            } set: { value in
                let feet = cm.map { Units.feetAndInches(cm: $0).feet } ?? 5
                cm = Units.centimetres(feet: feet, inches: Double(min(max(value ?? 0, 0), 11)))
            }
        }
    }

    extension View {
        /// A numeric keypad on iPhone instead of a fiddly picker (#22).
        func numericEntry() -> some View {
            #if os(iOS)
                keyboardType(.decimalPad)
            #else
                self
            #endif
        }
    }
#endif
