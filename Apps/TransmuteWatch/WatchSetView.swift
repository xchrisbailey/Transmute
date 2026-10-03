import SwiftUI
import TransmuteCore
import TransmuteUI

/// The set to do now: the exercise, "Set 3 of 5", one big number, and Log set. Tap a number
/// and turn the Digital Crown to change it before logging.
struct WatchSetView: View {
    let session: WatchSession
    let ref: SetRef
    let units: Units

    @State private var values = SetValues()
    @State private var focus = SetField.weight
    @State private var crown = 0.0
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var exercise: SessionSnapshot.Exercise? {
        session.snapshot.exercise(at: ref)
    }

    private var set: SessionSnapshot.Set? {
        session.snapshot.set(at: ref)
    }

    private var dial: SetDial {
        let known = session.library.exercise(id: exercise?.exerciseID ?? "")
        return SetDial(
            tracking: exercise?.tracking ?? known?.tracking ?? .weightReps, equipment: known?.allEquipment ?? [],
            units: units)
    }

    private var range: ClosedRange<Double> {
        dial.range(for: focus)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: exercise?.name ?? "")
                .brandFont(.label)
                .foregroundStyle(Color.brand(\.ink))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                Text(position)
                    .font(.footnote)
                    .foregroundStyle(Color.brandText(\.subtext))
                WatchHeartRate(bpm: session.live.heartRate)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ForEach(Array(dial.fields.enumerated()), id: \.element) { index, field in
                    number(field, isBig: index == 0)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Button {
                session.perform(.logSet(ref, values, at: .now))
            } label: {
                Label {
                    Text(Copy.logSet)
                } icon: {
                    Image(systemName: "checkmark")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brand(\.magic))
            .foregroundStyle(Color.watchScreen)
            .disabled(isLuminanceReduced)
        }
        .padding(.horizontal, 4)
        .focusable()
        .digitalCrownRotation(
            $crown, from: range.lowerBound, through: range.upperBound, by: dial.step(for: focus, in: values),
            sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true
        )
        .onChange(of: crown) { _, shown in
            // Focusing a field sets the crown to its value; only a real turn changes the set.
            guard abs(shown - dial.value(of: focus, in: values)) > 0.000_1 else { return }
            values = dial.setting(focus, to: shown, in: values)
        }
        .onAppear {
            values = set.map(SetValues.init) ?? SetValues()
            select(dial.fields.first ?? .weight)
        }
    }

    private var position: LocalizedStringResource {
        if set?.isWarmUp == true { return WatchCopy.warmUp }
        let working = exercise?.sets.filter { !$0.isWarmUp } ?? []
        let number = (working.firstIndex { $0.order == ref.setOrder } ?? 0) + 1
        return WatchCopy.setOf(number, of: max(working.count, 1))
    }

    private func select(_ field: SetField) {
        focus = field
        crown = dial.value(of: field, in: values)
    }

    /// One number with its unit underneath. The first is the screen's big number; the second
    /// is peach. The one the crown turns is marked with an arrow, not just by colour.
    private func number(_ field: SetField, isBig: Bool) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: dial.text(for: field, in: values))
                .font(isBig ? .brandBigNumber : .brandNumber(size: 30, relativeTo: .title))
                .foregroundStyle(isBig ? Color.brand(\.ink) : Color.brandText(\.now))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
            HStack(spacing: 2) {
                if focus == field, dial.fields.count > 1 {
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
                Text(unit(of: field))
            }
            .font(.caption2)
            .foregroundStyle(Color.brandText(\.subtext))
        }
        .contentShape(.rect)
        .onTapGesture { select(field) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label(of: field)))
        .accessibilityValue(Text(verbatim: spoken(field)))
        .accessibilityHint(Text(WatchCopy.crownHint))
        .accessibilityAddTraits(focus == field ? .isSelected : [])
        .accessibilityAdjustableAction { direction in
            values = dial.adjusting(field, by: direction == .increment ? 1 : -1, in: values)
            select(field)
        }
    }

    private func unit(of field: SetField) -> String {
        switch field {
        case .weight: units.weightSymbol
        case .reps: String(localized: WatchCopy.reps).lowercased()
        case .seconds: String(localized: WatchCopy.time).lowercased()
        case .meters: String(localized: WatchCopy.distance).lowercased()
        }
    }

    private func label(of field: SetField) -> LocalizedStringResource {
        switch field {
        case .weight: WatchCopy.weight
        case .reps: WatchCopy.reps
        case .seconds: WatchCopy.time
        case .meters: WatchCopy.distance
        }
    }

    /// The value as VoiceOver should say it: weight with its unit spelled out.
    private func spoken(_ field: SetField) -> String {
        guard field == .weight, let kg = values.weightKg else { return dial.text(for: field, in: values) }
        let unit: UnitMass = units.weight == .metric ? .kilograms : .pounds
        let shown = (units.displayWeight(kg: kg) * 2).rounded() / 2
        return Measurement(value: shown, unit: unit)
            .formatted(.measurement(width: .wide, usage: .asProvided).locale(units.locale))
    }
}
