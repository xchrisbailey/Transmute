import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

/// Weight, height and distance units (#18). Changes save straight away.
struct UnitsSection: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            Picker(selection: unit(\.weight)) {
                Text(SettingsScreenCopy.kilograms).tag(UnitSystem.metric)
                Text(SettingsScreenCopy.pounds).tag(UnitSystem.imperial)
            } label: {
                Text(SettingsScreenCopy.weight)
            }
            Picker(selection: unit(\.height)) {
                Text(SettingsScreenCopy.matchDevice).tag(UnitSystem?.none)
                Text(SettingsScreenCopy.centimetres).tag(UnitSystem?.some(.metric))
                Text(SettingsScreenCopy.feetAndInches).tag(UnitSystem?.some(.imperial))
            } label: {
                Text(SettingsScreenCopy.height)
            }
            Picker(selection: unit(\.distance)) {
                Text(SettingsScreenCopy.matchDevice).tag(UnitSystem?.none)
                Text(SettingsScreenCopy.kilometres).tag(UnitSystem?.some(.metric))
                Text(SettingsScreenCopy.miles).tag(UnitSystem?.some(.imperial))
            } label: {
                Text(SettingsScreenCopy.distance)
            }
        } header: {
            Text(SettingsScreenCopy.units)
        } footer: {
            Text(SettingsScreenCopy.unitsNote)
        }
    }

    private func unit<Value>(_ keyPath: WritableKeyPath<UnitSettings, Value>) -> Binding<Value> {
        Binding {
            UnitSettings(profile)[keyPath: keyPath]
        } set: { value in
            var settings = UnitSettings(profile)
            settings[keyPath: keyPath] = value
            settings.apply(to: profile)
            try? context.save()
        }
    }
}

/// Rows to the bar and plates setup (#21) and the progression settings (#12), which are the
/// same screens the Profile links to. Here they save straight away.
struct EquipmentLinksSection: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            NavigationLink {
                PlateSetupView(inventory: plates)
            } label: {
                Text(PlateCopy.setup)
            }
            NavigationLink {
                ProgressionSettingsView(profile: profile)
            } label: {
                Text(ProgressionCopy.title)
            }
        } header: {
            Text(SettingsScreenCopy.equipment)
        } footer: {
            Text(SettingsScreenCopy.equipmentNote)
        }
    }

    /// The profile keeps a copy of the chosen bar's weight, as saving a profile draft does.
    private var plates: Binding<PlateInventory> {
        Binding {
            profile.plates
        } set: { plates in
            profile.plates = plates
            profile.barbellKg = plates.barKg
            try? context.save()
        }
    }
}

/// System, Mocha or Latte, for this device (#18).
struct AppearanceSection: View {
    @AppStorage(Appearance.defaultsKey) private var appearance = Appearance.system

    var body: some View {
        Section {
            Picker(selection: $appearance) {
                ForEach(Appearance.allCases) { appearance in
                    Text(appearance.name).tag(appearance)
                }
            } label: {
                Text(SettingsScreenCopy.appearance)
            }
        } header: {
            Text(SettingsScreenCopy.appearance)
        } footer: {
            Text(SettingsScreenCopy.appearanceNote)
        }
    }
}

#Preview {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    // swiftlint:disable:next force_try
    let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
    return NavigationStack {
        Form {
            UnitsSection(profile: profile)
            EquipmentLinksSection(profile: profile)
            AppearanceSection()
        }
    }
    .modelContainer(container)
}
