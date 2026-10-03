import SwiftData
import SwiftUI
import TransmuteCore
import TransmutePlanUI
import TransmuteUI

/// How a workout runs and what its screens show (#18): rest times and alerts, RPE and % of
/// 1RM, and warm-up sets. Changes save straight away and reach the session on its next set.
struct WorkoutSections: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            Section {
                restPicker(SettingsScreenCopy.workingRest, seconds: $profile.preferences.workingRestSeconds)
                restPicker(SettingsScreenCopy.warmUpRest, seconds: $profile.preferences.warmUpRestSeconds)
            } header: {
                Text(SettingsScreenCopy.rest)
            } footer: {
                Text(SettingsScreenCopy.restNote)
            }
            Section {
                Toggle(isOn: $profile.preferences.autoStartRest) {
                    Text(SettingsScreenCopy.autoStartRest)
                }
                Toggle(isOn: $profile.preferences.restSound) {
                    Text(SettingsScreenCopy.restSound)
                }
                Toggle(isOn: $profile.preferences.restHaptics) {
                    Text(SettingsScreenCopy.restHaptics)
                }
            } header: {
                Text(SettingsScreenCopy.restAlerts)
            } footer: {
                Text(SettingsScreenCopy.restHapticsNote)
            }
            Section {
                effortPicker(
                    SettingsScreenCopy.showRPE, stored: $profile.preferences.showRPE,
                    automaticShows: WorkoutPreferences().showsRPE(for: profile.experience))
                effortPicker(
                    SettingsScreenCopy.showPercentOfMax, stored: $profile.preferences.showPercentOfMax,
                    automaticShows: WorkoutPreferences().showsPercentOfMax(for: profile.experience))
            } header: {
                Text(SettingsScreenCopy.setsShow)
            } footer: {
                // The same one-line explanations as the plan's "What's this?" glossary.
                VStack(alignment: .leading, spacing: 6) {
                    Text(PlanCopy.rpeHelp)
                    Text(PlanCopy.oneRepMaxHelp)
                    Text(SettingsScreenCopy.effortNote)
                }
            }
            Section {
                Toggle(isOn: $profile.preferences.warmUpSets) {
                    Text(SettingsScreenCopy.warmUpSets)
                }
            } footer: {
                Text(SettingsScreenCopy.warmUpSetsNote)
            }
        }
        .tint(Color.brand(\.magic))
        .onChange(of: profile.preferences) {
            try? context.save()
        }
    }

    private func restPicker(_ label: LocalizedStringResource, seconds: Binding<Double>) -> some View {
        Picker(selection: seconds) {
            ForEach(RestChoices.including(seconds.wrappedValue), id: \.self) { choice in
                Text(verbatim: RestChoices.label(choice)).tag(choice)
            }
        } label: {
            Text(label)
        }
    }

    private func effortPicker(
        _ label: LocalizedStringResource, stored: Binding<Bool?>, automaticShows: Bool
    ) -> some View {
        let choice = Binding {
            EffortChoice(stored.wrappedValue)
        } set: {
            stored.wrappedValue = $0.stored
        }
        return Picker(selection: choice) {
            ForEach(EffortChoice.allCases, id: \.self) { choice in
                Text(choice.label(automaticShows: automaticShows)).tag(choice)
            }
        } label: {
            Text(label)
        }
    }
}

#Preview {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    // swiftlint:disable:next force_try
    let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
    return Form {
        WorkoutSections(profile: profile)
    }
    .modelContainer(container)
}
