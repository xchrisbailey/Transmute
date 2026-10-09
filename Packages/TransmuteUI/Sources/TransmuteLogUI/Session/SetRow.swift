import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// The fields a set table shows, by how the exercise is measured.
enum SetColumn: CaseIterable {
    case weight, reps, distance, time, rounds

    static func columns(for tracking: TrackingType) -> [SetColumn] {
        switch tracking {
        case .weightReps: [.weight, .reps]
        case .reps: [.reps]
        case .time: [.time]
        case .distanceTime: [.distance, .time]
        case .intervals: [.rounds, .time]
        }
    }

    func title(units: Units) -> Text {
        switch self {
        case .weight: Text(verbatim: units.weightSymbol)
        case .reps: Text(LogCopy.reps)
        case .distance: Text(LogCopy.distance)
        case .time: Text(LogCopy.time)
        case .rounds: Text(LogCopy.rounds)
        }
    }

    /// What the field is called when a large-text row stacks and the header is gone.
    var name: LocalizedStringResource {
        switch self {
        case .weight: LogCopy.weight
        case .reps: LogCopy.reps
        case .distance: LogCopy.distance
        case .time: LogCopy.time
        case .rounds: LogCopy.rounds
        }
    }

    /// The column's value for a set, or a dash when it's empty.
    func value(of set: LoggedSet, units: Units) -> String {
        let dash = "–"
        switch self {
        case .weight:
            return set.weightKg.map { Self.number(units.displayWeight(kg: $0)) } ?? dash
        case .reps:
            return set.reps.map(String.init) ?? dash
        case .distance:
            return set.meters.map { units.formatDistance(meters: $0) } ?? dash
        case .time:
            return set.seconds.map { Units.clock(seconds: $0) } ?? dash
        case .rounds:
            return set.rounds.map(String.init) ?? dash
        }
    }

    /// e.g. 102.5 or 225, rounded to the half unit like everywhere else.
    static func number(_ value: Double) -> String {
        ((value * 2).rounded() / 2).formatted(.number.precision(.fractionLength(0...1)))
    }
}

/// Set · kg/lb · Reps · ✓, over the rows of one exercise.
struct SetTableHeader: View {
    let tracking: TrackingType
    let units: Units

    var body: some View {
        HStack {
            Text(LogCopy.set)
                .frame(width: 44, alignment: .leading)
            ForEach(SetColumn.columns(for: tracking), id: \.self) { column in
                column.title(units: units)
                    .frame(maxWidth: .infinity)
            }
            Image(systemName: "checkmark")
                .frame(width: 44)
        }
        .brandFont(.label)
        .foregroundStyle(Color.brandText(\.subtext))
        .accessibilityHidden(true)
    }
}

/// One set: its numbers and a check. The current set is outlined in peach and done sets turn
/// green. Tapping a row opens steppers and fields to change it before checking it off.
struct SetRow: View {
    @Bindable var set: LoggedSet
    let number: Int
    let total: Int
    let tracking: TrackingType
    let equipment: Set<Equipment>
    let units: Units
    /// The bar and plates, for barbell work only.
    let plates: PlateInventory?
    let isCurrent: Bool
    let isEditing: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    let onNote: () -> Void
    let onRemove: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the columns can't share a line, so each field gets its own.
    private var stacks: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            figures
                .contentShape(.rect)
                .onTapGesture(perform: onTap)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityInputLabels([Text(voiceControlName), accessibilityLabel])
                .accessibilityValue(Text(set.isCompleted ? LogCopy.logged : LogCopy.notLogged))
                .accessibilityHint(isCurrent ? Text(LogCopy.current) : Text(verbatim: ""))
                .accessibilityAction(named: Text(set.isCompleted ? LogCopy.undoSet : Copy.logSet), onToggle)
                .accessibilityAction(named: Text(LogCopy.notes), onNote)
                .accessibilityAction(.default, onTap)

            if !set.notes.isEmpty {
                Text(verbatim: set.notes)
                    .brandFont(.label)
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if isEditing && !set.isCompleted {
                SetEditor(
                    set: set, tracking: tracking, equipment: equipment, units: units, plates: plates,
                    onDone: onToggle)
                if stacks {
                    VStack(alignment: .leading) {
                        noteButton
                        removeButton
                    }
                    .buttonStyle(.borderless)
                    .brandFont(.label)
                } else {
                    HStack {
                        noteButton
                        Spacer()
                        removeButton
                    }
                    .buttonStyle(.borderless)
                    .brandFont(.label)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(background)
    }

    /// What the row shows and Voice Control and VoiceOver read, as one element.
    private var figures: some View {
        VStack(alignment: .leading, spacing: 6) {
            if stacks {
                stackedFigures
            } else {
                tabularFigures
            }
            if set.holdsRecord {
                recordLine
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Set · figures · check, lined up under the header.
    private var tabularFigures: some View {
        HStack {
            Text(verbatim: set.isWarmUp ? "W" : "\(number)")
                .brandNumberFont(size: 17)
                .foregroundStyle(Color.brandText(\.subtext))
                .frame(width: 44, alignment: .leading)
            ForEach(SetColumn.columns(for: tracking), id: \.self) { column in
                Text(verbatim: column.value(of: set, units: units))
                    .brandNumberFont(size: 20, relativeTo: .title3)
                    .foregroundStyle(Color.brand(\.ink))
                    .frame(maxWidth: .infinity)
            }
            checkButton
        }
    }

    /// The set's name and check, then each field under its own name. There's no header above.
    private var stackedFigures: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(voiceControlName)
                    .brandNumberFont(size: 17)
                    .foregroundStyle(Color.brandText(\.subtext))
                Spacer(minLength: 8)
                checkButton
            }
            ForEach(SetColumn.columns(for: tracking), id: \.self) { column in
                VStack(alignment: .leading, spacing: 0) {
                    Text(column.name)
                        .brandFont(.label)
                        .foregroundStyle(Color.brandText(\.subtext))
                    Text(verbatim: stackedValue(of: column))
                        .brandNumberFont(size: 20, relativeTo: .title3)
                        .foregroundStyle(Color.brand(\.ink))
                }
            }
        }
    }

    /// The load carries its unit, since the header that held it is gone.
    private func stackedValue(of column: SetColumn) -> String {
        let value = column.value(of: set, units: units)
        guard column == .weight, set.weightKg != nil else { return value }
        return "\(value) \(units.weightSymbol)"
    }

    /// The lasting mark of a record: the toast's medal in gold, and what the record was.
    private var recordLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "medal.fill")
                .foregroundStyle(Color.brand(\.gold))
            Text(
                verbatim: set.recordMarks.map { String(localized: RecordFormat.label($0, units: units)) }
                    .joined(separator: " · ")
            )
            .foregroundStyle(Color.brandText(\.gold))
        }
        .brandFont(.label)
    }

    private var noteButton: some View {
        Button(action: onNote) {
            Label {
                Text(LogCopy.notes)
            } icon: {
                Image(systemName: "note.text")
            }
        }
    }

    private var removeButton: some View {
        Button(role: .destructive, action: onRemove) {
            Label {
                Text(LogCopy.removeSet)
            } icon: {
                Image(systemName: "minus.circle")
            }
        }
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(set.isCompleted ? Color.brandText(\.done) : Color.brandText(\.subtext))
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.impact(weight: .light), trigger: set.isCompleted)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var background: some View {
        if set.isCompleted {
            Color.brand(\.done).opacity(0.18)
        } else if isCurrent {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.brand(\.now), lineWidth: 2)
                .background(Color.brand(\.mantle))
        } else {
            Color.brand(\.mantle)
        }
    }

    private var accessibilityLabel: Text {
        let values = SetColumn.columns(for: tracking).map { column in
            switch column {
            case .weight: set.weightKg.map { units.formatWeight(kg: $0) } ?? ""
            case .reps: set.reps.map { String(localized: LogCopy.repsCount($0)) } ?? ""
            default: column.value(of: set, units: units)
            }
        }
        let prefix =
            set.isWarmUp ? String(localized: LogCopy.warmUp) : String(localized: LogCopy.setOf(number, of: total))
        let record = set.holdsRecord ? [String(localized: LogCopy.personalRecord)] : []
        return Text(verbatim: ([prefix] + values.filter { !$0.isEmpty } + record).joined(separator: ", "))
    }

    /// "Set 3" or "Warm-up 1": what someone says to tap the row, and what the stacked row shows.
    private var voiceControlName: LocalizedStringResource {
        self.set.isWarmUp ? LogCopy.warmUpNumber(set.warmUpNumber ?? number) : LogCopy.setNumber(number)
    }
}

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
