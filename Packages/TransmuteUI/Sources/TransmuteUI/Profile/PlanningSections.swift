#if !os(watchOS)
    import SwiftUI
    import TransmuteCore

    struct ScheduleSection: View {
        @Binding var draft: ProfileDraft

        var body: some View {
            Section {
                Stepper(value: $draft.schedule.daysPerWeek, in: ProfileDraft.daysRange) {
                    Text(ProfileCopy.daysPerWeek(draft.schedule.daysPerWeek))
                }
                .onChange(of: draft.schedule.daysPerWeek) { _, days in
                    draft.schedule.preferredWeekdays = ProfileDraft.suggestedWeekdays(
                        days: days, commitments: draft.schedule.commitments)
                }
                VStack(alignment: .leading) {
                    Text(ProfileCopy.whichDays)
                        .brandFont(.label)
                    ChipFlow(items: Array(1...7)) { weekday in
                        Chip(
                            label: LocalizedStringResource(stringLiteral: WeekdayNames.short(weekday)),
                            isOn: day(weekday)
                        )
                        .accessibilityLabel(Text(verbatim: WeekdayNames.full(weekday)))
                    }
                    if draft.scheduleIssues.contains(.weekdaysDontMatchDays) {
                        Text(ProfileCopy.pickDays(draft.schedule.daysPerWeek))
                            .brandFont(.label)
                            .foregroundStyle(Color.brandText(\.alert))
                    }
                }
                Stepper(value: $draft.schedule.sessionMinutes, in: ProfileDraft.sessionRange, step: 15) {
                    Text(ProfileCopy.sessionLength(draft.schedule.sessionMinutes))
                }
                Stepper(value: $draft.schedule.weeks, in: ProfileDraft.weeksRange) {
                    Text(ProfileCopy.planLength(draft.schedule.weeks))
                }
            }
            if !draft.sport.isEmpty {
                Section {
                    ForEach($draft.schedule.commitments, id: \.self) { $commitment in
                        CommitmentRow(commitment: $commitment)
                    }
                    .onDelete { draft.schedule.commitments.remove(atOffsets: $0) }
                    Button {
                        let used = Set(draft.schedule.commitments.map(\.weekday))
                        let weekday = (1...7).reversed().first { !used.contains($0) } ?? 6
                        draft.schedule.commitments.append(
                            Commitment(
                                weekday: weekday, label: String(localized: ProfileCopy.defaultCommitment),
                                intensity: .hard))
                    } label: {
                        Label {
                            Text(ProfileCopy.addCommitment)
                        } icon: {
                            Image(systemName: "plus")
                        }
                    }
                } header: {
                    Text(ProfileCopy.commitments)
                } footer: {
                    Text(ProfileCopy.commitmentsNote)
                }
            }
        }

        private func day(_ weekday: Weekday) -> Binding<Bool> {
            Binding {
                draft.schedule.preferredWeekdays.contains(weekday)
            } set: { isOn in
                draft.schedule.preferredWeekdays.removeAll { $0 == weekday }
                if isOn { draft.schedule.preferredWeekdays.append(weekday) }
                draft.schedule.preferredWeekdays.sort()
            }
        }
    }

    struct CommitmentRow: View {
        @Binding var commitment: Commitment

        var body: some View {
            VStack(alignment: .leading) {
                TextField(text: $commitment.label) {
                    Text(ProfileCopy.commitmentLabel)
                }
                Picker(selection: $commitment.weekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(verbatim: WeekdayNames.full(weekday)).tag(weekday)
                    }
                } label: {
                    Text(ProfileCopy.day)
                }
                Picker(selection: $commitment.intensity) {
                    ForEach(Commitment.Intensity.allCases, id: \.self) { intensity in
                        Text(intensity.label).tag(intensity)
                    }
                } label: {
                    Text(ProfileCopy.intensity)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    struct EquipmentSection: View {
        @Binding var draft: ProfileDraft
        /// On the Profile screen, a row to the full bar and plates setup (#21) stands in for the
        /// bar weight; onboarding keeps just the bar weight.
        var linksPlateSetup = false
        @State private var showsEverything = false

        var body: some View {
            Section {
                Picker(selection: preset) {
                    ForEach(EquipmentPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(EquipmentPreset?.some(preset))
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
                .labelsHidden()
                DisclosureGroup(isExpanded: $showsEverything) {
                    ForEach(Equipment.allCases.filter { $0 != .bodyweight }, id: \.self) { item in
                        Toggle(isOn: has(item)) {
                            Text(item.label)
                        }
                    }
                } label: {
                    Text(ProfileCopy.everything)
                }
            }
            if linksPlateSetup {
                Section {
                    NavigationLink {
                        PlateSetupView(inventory: $draft.plates)
                    } label: {
                        Text(PlateCopy.setup)
                    }
                } footer: {
                    Text(PlateCopy.setupNote)
                }
            } else if draft.equipment.contains(.barbell) {
                Section {
                    WeightField(
                        label: ProfileCopy.barbellWeight, kg: barbell, units: Units(system: draft.unitSystem))
                }
            }
        }

        private var preset: Binding<EquipmentPreset?> {
            Binding {
                EquipmentPreset.matching(draft.equipment)
            } set: { preset in
                if let preset { draft.equipment = preset.equipment }
            }
        }

        private var barbell: Binding<Double?> {
            Binding {
                draft.barbellKg
            } set: {
                draft.barbellKg = $0 ?? 20
            }
        }

        private func has(_ item: Equipment) -> Binding<Bool> {
            Binding {
                draft.equipment.contains(item)
            } set: { isOn in
                if isOn { draft.equipment.insert(item) } else { draft.equipment.remove(item) }
                draft.equipment.insert(.bodyweight)
            }
        }
    }

    struct LimitationsSection: View {
        @Binding var draft: ProfileDraft

        var body: some View {
            Section {
                TextField(text: $draft.limitations, axis: .vertical) {
                    Text(ProfileCopy.limitationsPrompt)
                }
                .lineLimit(2...5)
                .brandFont(.body)
            } footer: {
                Text(ProfileCopy.limitationsNote)
            }
            Section {
                ChipFlow(items: BodyArea.allCases) { area in
                    Chip(label: area.label, isOn: binding(for: area))
                }
                .padding(.vertical, 4)
            } header: {
                Text(ProfileCopy.areas)
            }
        }

        private func binding(for area: BodyArea) -> Binding<Bool> {
            Binding {
                draft.limitationAreas.contains(area)
            } set: { isOn in
                if isOn { draft.limitationAreas.insert(area) } else { draft.limitationAreas.remove(area) }
            }
        }
    }
#endif
