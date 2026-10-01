#if !os(watchOS)
    import SwiftData
    import SwiftUI
    import TransmuteCore

    /// Load increments for upper and lower body, in the profile's units, and the exercises the
    /// person is holding (#12). Changes save straight away.
    public struct ProgressionSettingsView: View {
        @Bindable var profile: Profile
        @Environment(\.modelContext) private var context
        @Query private var customExercises: [CustomExercise]
        private let library: ExerciseLibrary

        public init(profile: Profile, library: ExerciseLibrary = .bundled) {
            self.profile = profile
            self.library = library
        }

        public var body: some View {
            Form {
                Section {
                    incrementPicker(.upper, label: ProgressionCopy.upperBody)
                    incrementPicker(.lower, label: ProgressionCopy.lowerBody)
                } header: {
                    Text(ProgressionCopy.increments)
                } footer: {
                    Text(ProgressionCopy.incrementsNote)
                }
                Section {
                    if profile.progression.heldExerciseIDs.isEmpty {
                        Text(ProgressionCopy.noneHeld)
                            .foregroundStyle(Color.brandText(\.subtext))
                    }
                    ForEach(profile.progression.heldExerciseIDs, id: \.self) { exerciseID in
                        heldRow(exerciseID)
                    }
                    .onDelete { offsets in
                        for exerciseID in offsets.map({ profile.progression.heldExerciseIDs[$0] }) {
                            release(exerciseID)
                        }
                    }
                } header: {
                    Text(ProgressionCopy.held)
                } footer: {
                    Text(ProgressionCopy.heldNote)
                }
            }
            .navigationTitle(Text(ProgressionCopy.title))
        }

        private var system: UnitSystem {
            profile.unitSystem ?? .preferred()
        }

        private func incrementPicker(_ region: BodyRegion, label: LocalizedStringResource) -> some View {
            Picker(selection: increment(region)) {
                ForEach(ProgressionSettings.incrementChoices(for: system), id: \.self) { value in
                    Text(verbatim: format(value))
                        .brandNumberFont(size: 17)
                        .tag(value)
                }
            } label: {
                Text(label)
            }
        }

        private func heldRow(_ exerciseID: String) -> some View {
            let name = name(of: exerciseID)
            return HStack {
                Text(verbatim: name)
                Spacer()
                Button {
                    release(exerciseID)
                } label: {
                    Text(ProgressionCopy.letItProgress)
                }
                .buttonStyle(.borderless)
                .frame(minHeight: 44)
                .accessibilityLabel(Text(ProgressionCopy.letNamedProgress(name)))
            }
        }

        private func increment(_ region: BodyRegion) -> Binding<Double> {
            Binding {
                profile.progression.increment(for: region, system: system)
            } set: { value in
                profile.progression.setIncrement(value, for: region, system: system)
                try? context.save()
            }
        }

        private func release(_ exerciseID: String) {
            profile.progression.setHeld(false, exerciseID)
            try? context.save()
        }

        private func name(of exerciseID: String) -> String {
            library.exercise(id: exerciseID)?.name
                ?? customExercises.first { $0.exerciseID == exerciseID }?.name
                ?? exerciseID
        }

        /// e.g. "1.25 kg" or "2.5 lb". Not `Units.formatWeight`, which rounds to the half.
        private func format(_ value: Double) -> String {
            let units = Units(system: system)
            let number = value.formatted(.number.precision(.fractionLength(0...2)).locale(units.locale))
            return "\(number) \(units.weightSymbol)"
        }
    }

    #Preview {
        let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
        // swiftlint:disable:next force_try
        let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
        profile.progression.setHeld(true, "back-squat")
        return NavigationStack {
            ProgressionSettingsView(profile: profile)
        }
        .modelContainer(container)
    }
#endif
