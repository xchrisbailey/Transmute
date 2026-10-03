#if !os(watchOS)
    import SwiftUI
    import TransmuteCore

    // Form sections for each part of the profile. Onboarding shows one per step; the Profile
    // screen shows them all in one form.

    struct BodySection: View {
        @Binding var draft: ProfileDraft
        /// Onboarding asks for the units here. Afterwards they're chosen in Settings (#18), so
        /// the Profile screen leaves the picker out.
        var showsUnits = true

        var body: some View {
            let units = draft.units
            Section {
                if showsUnits {
                    Picker(selection: $draft.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.label).tag(system)
                        }
                    } label: {
                        Text(ProfileCopy.units)
                    }
                    .pickerStyle(.segmented)
                }
                HeightField(cm: $draft.heightCm, system: draft.units.height)
                WeightField(label: ProfileCopy.weight, kg: $draft.weightKg, units: units)
                LabeledContent {
                    TextField(value: $draft.birthYear, format: .number.grouping(.never)) {
                        Text(ProfileCopy.birthYear)
                    }
                    .numericEntry()
                    .multilineTextAlignment(.trailing)
                    .brandNumberFont(size: 17)
                } label: {
                    Text(ProfileCopy.birthYear)
                }
                Picker(selection: $draft.sex) {
                    Text(ProfileCopy.preferNotToSay).tag(Sex?.none)
                    ForEach(Sex.allCases, id: \.self) { sex in
                        Text(sex.label).tag(Sex?.some(sex))
                    }
                } label: {
                    Text(ProfileCopy.sex)
                    Text(ProfileCopy.sexNote)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(draft.bodyIssues.filter(\.isShown), id: \.self) { issue in
                        Label {
                            Text(issue.message)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                        }
                        .foregroundStyle(Color.brandText(\.alert))
                    }
                }
            }
        }
    }

    extension ProfileDraft.Issue {
        /// Missing values just keep Continue disabled; only wrong ones get a message.
        var isShown: Bool {
            self != .heightMissing && self != .weightMissing
        }

        var message: LocalizedStringResource {
            switch self {
            case .heightMissing, .heightOutOfRange: ProfileCopy.checkHeight
            case .weightMissing, .weightOutOfRange: ProfileCopy.checkWeight
            case .birthYearOutOfRange: ProfileCopy.checkBirthYear
            case .daysOutOfRange, .weekdaysDontMatchDays: ProfileCopy.pickDays(0)
            }
        }
    }

    struct ExperienceSection: View {
        @Binding var draft: ProfileDraft

        static let mainLifts = ["back-squat", "bench-press", "deadlift", "overhead-press"]

        var body: some View {
            Section {
                ForEach(ExperienceLevel.allCases, id: \.self) { level in
                    Button {
                        draft.experience = level
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.label)
                                    .brandFont(.exerciseTitle)
                                    .foregroundStyle(Color.brand(\.ink))
                                Text(level.detail)
                                    .brandFont(.body)
                                    .foregroundStyle(Color.brandText(\.subtext))
                            }
                            Spacer()
                            Image(systemName: draft.experience == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    draft.experience == level ? Color.brand(\.magic) : Color.brand(\.overlay0)
                                )
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(draft.experience == level ? [.isSelected, .isButton] : .isButton)
                }
            }
            if draft.experience == .advanced {
                Section {
                    ForEach(Self.mainLifts, id: \.self) { id in
                        KnownLiftRow(exerciseID: id, lifts: $draft.knownLifts, units: draft.units)
                    }
                } header: {
                    Text(ProfileCopy.knownLiftsTitle)
                } footer: {
                    Text(ProfileCopy.knownLiftsNote)
                }
            }
        }
    }

    /// Weight × reps for one main lift. Empty means not entered.
    struct KnownLiftRow: View {
        let exerciseID: String
        @Binding var lifts: [KnownLift]
        let units: Units

        var body: some View {
            let name = ExerciseLibrary.bundled.exercise(id: exerciseID)?.name ?? exerciseID
            VStack(alignment: .leading) {
                Text(verbatim: name)
                    .brandFont(.label)
                HStack {
                    WeightField(label: ProfileCopy.weight, kg: weight, units: units)
                    TextField(value: reps, format: .number) {
                        Text(ProfileCopy.reps)
                    }
                    .numericEntry()
                    .multilineTextAlignment(.trailing)
                    .brandNumberFont(size: 17)
                    .frame(maxWidth: 60)
                    .accessibilityLabel(Text(ProfileCopy.reps))
                    Text(verbatim: "×")
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text(verbatim: name))
        }

        private var index: Int? {
            lifts.firstIndex { $0.exerciseID == exerciseID }
        }

        private var weight: Binding<Double?> {
            Binding {
                index.map { lifts[$0].weightKg }
            } set: { value in
                if let value {
                    if let index {
                        lifts[index].weightKg = value
                    } else {
                        lifts.append(KnownLift(exerciseID: exerciseID, weightKg: value, reps: 1))
                    }
                } else if let index {
                    lifts.remove(at: index)
                }
            }
        }

        private var reps: Binding<Int?> {
            Binding {
                index.map { lifts[$0].reps }
            } set: { value in
                if let index { lifts[index].reps = max(1, min(value ?? 1, 30)) }
            }
        }
    }

    struct GoalSection: View {
        @Binding var draft: ProfileDraft

        var body: some View {
            Section {
                TextField(text: $draft.goalText, axis: .vertical) {
                    Text(ProfileCopy.goalPrompt)
                }
                .lineLimit(2...5)
                .brandFont(.body)
            }
            Section {
                ChipFlow(items: GoalChoice.allCases) { choice in
                    Chip(label: choice.label, isOn: tag(choice.tag))
                }
                .padding(.vertical, 4)
            } header: {
                Text(ProfileCopy.goalChips)
            }
        }

        private func tag(_ tag: GoalTag) -> Binding<Bool> {
            Binding {
                draft.goalTags.contains(tag)
            } set: { isOn in
                draft.goalTags.removeAll { $0 == tag }
                if isOn { draft.goalTags.append(tag) }
            }
        }
    }

    struct SportSection: View {
        @Binding var draft: ProfileDraft

        var body: some View {
            Section {
                TextField(text: $draft.sport, axis: .vertical) {
                    Text(ProfileCopy.sportPrompt)
                }
                .lineLimit(1...3)
                .brandFont(.body)
            } footer: {
                Text(ProfileCopy.sportNote)
            }
            .onAppear {
                if draft.sport.isEmpty, let sport = ProfileDraft.mentionedSport(in: draft.goalText), sport != "court" {
                    draft.sport = sport
                }
            }
        }
    }
#endif
