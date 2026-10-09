import SwiftUI
import TransmuteUI

/// − value + with a number field in the middle: tap the buttons, or type.
struct NumberStepper: View {
    let label: Text
    let unit: String?
    @Binding var value: Double?
    let step: Double
    let range: ClosedRange<Double>
    var fractionDigits = 1

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the name sits above the buttons and the number gets the width.
    private var stacks: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if stacks {
                VStack(alignment: .leading, spacing: 8) {
                    nameLabel
                    HStack(spacing: 12) { controls }
                }
            } else {
                HStack(spacing: 12) {
                    nameLabel
                        .frame(maxWidth: .infinity, alignment: .leading)
                    controls
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: nudge(by: step)
            case .decrement: nudge(by: -step)
            @unknown default: break
            }
        }
    }

    private var nameLabel: some View {
        label
            .brandFont(.label)
            .foregroundStyle(Color.brandText(\.subtext))
    }

    /// − number unit +
    @ViewBuilder private var controls: some View {
        button("minus", by: -step)
        TextField(value: $value, format: .number.precision(.fractionLength(0...fractionDigits))) {
            label
        }
        .multilineTextAlignment(.center)
        .brandNumberFont(size: 22, relativeTo: .title2)
        .frame(minWidth: 64, maxWidth: stacks ? .infinity : 96)
        #if os(iOS)
            .keyboardType(fractionDigits > 0 ? .decimalPad : .numberPad)
        #endif
        if let unit {
            Text(verbatim: unit)
                .brandFont(.label)
                .foregroundStyle(Color.brandText(\.subtext))
                .accessibilityHidden(true)
        }
        button("plus", by: step)
    }

    private func button(_ symbol: String, by delta: Double) -> some View {
        Button {
            nudge(by: delta)
        } label: {
            Image(systemName: "\(symbol).circle.fill")
                .font(.title)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(Color.brand(\.surface1), Color.brand(\.ink))
        }
        .buttonStyle(.borderless)
        .accessibilityHidden(true)
    }

    private func nudge(by delta: Double) {
        let new = (value ?? (delta > 0 ? range.lowerBound : 0)) + (value == nil && delta > 0 ? 0 : delta)
        value = min(max(new, range.lowerBound), range.upperBound)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}
