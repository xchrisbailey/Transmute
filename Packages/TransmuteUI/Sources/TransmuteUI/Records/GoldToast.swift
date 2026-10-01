import SwiftUI
import TransmuteCore

/// The in-session toast for a new record: "Gold. Squat 5RM, 115 kg." with a success haptic.
///
/// Show it for the headline of `RecordBook.check(_:)`. The haptic plays when `trigger`
/// changes, so pass something that changes once per record, such as the record's id.
///
///     if let record = check.gold.first {
///         GoldToast(record.mark, exercise: name, units: units, trigger: record.persistentModelID)
///     }
public struct GoldToast<Trigger: Equatable>: View {
    let mark: RecordMark
    let exercise: String
    let units: Units
    let trigger: Trigger

    public init(_ mark: RecordMark, exercise: String, units: Units, trigger: Trigger) {
        self.mark = mark
        self.exercise = exercise
        self.units = units
        self.trigger = trigger
    }

    private var message: LocalizedStringResource {
        RecordFormat.gold(mark, exercise: exercise, units: units)
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "medal.fill")
                .font(.title3)
                .foregroundStyle(Color.brand(\.gold))
                .accessibilityHidden(true)
            Text(message)
                .brandFont(.body)
                .foregroundStyle(Color.brand(\.ink))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(Color.brand(\.mantle), in: .capsule)
        .overlay(Capsule().strokeBorder(Color.brand(\.gold), lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(message))
        .sensoryFeedback(.success, trigger: trigger)
    }
}

#Preview {
    GoldToast(
        RecordMark(kind: .repMax, value: 115, reps: 5), exercise: "Squat", units: Units(system: .metric), trigger: 1
    )
    .padding()
}
