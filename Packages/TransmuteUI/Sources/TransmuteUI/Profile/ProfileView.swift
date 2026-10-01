#if !os(watchOS)
    import SwiftData
    import SwiftUI
    import TransmuteCore

    /// Everything from onboarding, editable later, plus bodyweight history from manual entries
    /// and Health (#6, #7).
    public struct ProfileView: View {
        @Bindable var profile: Profile
        @Environment(\.modelContext) private var context
        @Environment(\.health) private var health
        @State private var draft: ProfileDraft
        @State private var newWeight: Double?

        public init(profile: Profile) {
            self.profile = profile
            _draft = State(initialValue: ProfileDraft(profile))
        }

        public var body: some View {
            Form {
                BodySection(draft: $draft)
                ExperienceSection(draft: $draft)
                GoalSection(draft: $draft)
                if draft.suggestsSport || !draft.sport.isEmpty {
                    SportSection(draft: $draft)
                }
                ScheduleSection(draft: $draft)
                EquipmentSection(draft: $draft, linksPlateSetup: true)
                LimitationsSection(draft: $draft)
                Section {
                    NavigationLink {
                        ProgressionSettingsView(profile: profile)
                    } label: {
                        Text(ProgressionCopy.title)
                    }
                }
                bodyweightHistory
            }
            .navigationTitle(Text(ProfileCopy.profile))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text(ProfileCopy.save)
                    }
                    .disabled(!draft.isComplete || draft == ProfileDraft(profile))
                }
            }
        }

        private var units: Units {
            Units(system: draft.unitSystem)
        }

        private var bodyweightHistory: some View {
            Section {
                HStack {
                    WeightField(label: ProfileCopy.addWeight, kg: $newWeight, units: units)
                    Button {
                        Task { await addWeight() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel(Text(ProfileCopy.addWeight))
                    }
                    .buttonStyle(.borderless)
                    .disabled(newWeight.map { !ProfileDraft.weightRange.contains($0) } ?? true)
                }
                let entries = (profile.bodyweights ?? []).sorted { $0.date > $1.date }
                if entries.isEmpty {
                    Text(ProfileCopy.noWeights)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
                ForEach(entries) { entry in
                    LabeledContent {
                        Text(verbatim: units.formatWeight(kg: entry.kg))
                            .brandNumberFont(size: 17)
                    } label: {
                        Text(entry.date, format: .dateTime.day().month().year())
                        if entry.healthKitSampleID != nil {
                            Text(ProfileCopy.fromHealth)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(entry)
                        } label: {
                            Text(ProfileCopy.deleteWeight)
                        }
                    }
                }
                if health.isAvailable {
                    Button {
                        Task { await importFromHealth() }
                    } label: {
                        Label {
                            Text(ProfileCopy.importFromHealth)
                        } icon: {
                            Image(systemName: "heart.fill")
                        }
                    }
                }
            } header: {
                Text(ProfileCopy.bodyweight)
            }
        }

        private func save() {
            draft.apply(to: profile)
            try? context.save()
            draft = ProfileDraft(profile)
        }

        /// Saves the weight here and, when allowed, to Health too. The Health sample's id is
        /// kept on the entry so importing never brings it back as a duplicate.
        private func addWeight() async {
            guard let kg = newWeight else { return }
            let entry = BodyweightEntry(kg: kg)
            profile.bodyweights?.append(entry)
            newWeight = nil
            draft.weightKg = kg
            if health.isAvailable {
                try? await health.requestAccess(.profile)
                entry.healthKitSampleID = try? await health.saveBodyweight(kg: kg, at: entry.date)
            }
            try? context.save()
        }

        private func importFromHealth() async {
            try? await health.requestAccess(.profile)
            let since = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .distantPast
            HealthImport.merge(await health.bodyweights(since: since), into: profile)
            try? context.save()
        }
    }

    #Preview {
        let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
        // swiftlint:disable:next force_try
        let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
        return NavigationStack {
            ProfileView(profile: profile)
        }
        .modelContainer(container)
    }
#endif
