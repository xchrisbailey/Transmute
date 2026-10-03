import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteIntelligence
import TransmuteUI

/// The groups Settings is split into: tabs on the Mac, one after another on the iPhone.
enum SettingsPane: String, CaseIterable, Identifiable {
    case general, workout, intelligence, health, data

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .general: SettingsScreenCopy.paneGeneral
        case .workout: SettingsScreenCopy.paneWorkout
        case .intelligence: SettingsScreenCopy.paneIntelligence
        case .health: SettingsScreenCopy.paneHealth
        case .data: SettingsScreenCopy.paneData
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .workout: "timer"
        case .intelligence: "sparkles"
        case .health: "heart"
        case .data: "hand.raised"
        }
    }
}

/// Settings (#18): units, equipment, workout, Apple Intelligence, Health, appearance, iCloud,
/// and privacy with export, import and delete-all.
///
/// On the iPhone it's one form, pushed onto a navigation stack. On the Mac it's the tabs of the
/// Settings window, where there may be no profile yet: the settings that live on the profile
/// wait until onboarding is done.
public struct SettingsView: View {
    let profile: Profile?
    let service: any IntelligenceService

    public init(profile: Profile?, service: any IntelligenceService) {
        self.profile = profile
        self.service = service
    }

    public var body: some View {
        #if os(macOS)
            TabView {
                ForEach(SettingsPane.allCases) { pane in
                    Tab {
                        NavigationStack {
                            Form {
                                SettingsPaneSections(pane: pane, profile: profile, service: service)
                            }
                            .formStyle(.grouped)
                        }
                    } label: {
                        Label {
                            Text(pane.title)
                        } icon: {
                            Image(systemName: pane.symbol)
                        }
                    }
                }
            }
            .frame(width: 600, height: 560)
        #else
            Form {
                ForEach(SettingsPane.allCases) { pane in
                    SettingsPaneSections(pane: pane, profile: profile, service: service)
                }
            }
            .navigationTitle(Text(SettingsCopy.title))
        #endif
    }
}

/// The sections of one pane.
struct SettingsPaneSections: View {
    let pane: SettingsPane
    let profile: Profile?
    let service: any IntelligenceService

    var body: some View {
        switch pane {
        case .general:
            if let profile {
                UnitsSection(profile: profile)
                EquipmentLinksSection(profile: profile)
            }
            AppearanceSection()
        case .workout:
            if let profile {
                WorkoutSections(profile: profile)
            } else {
                Section {
                    Text(SettingsScreenCopy.needsProfile)
                        .foregroundStyle(Color.brandText(\.subtext))
                }
            }
        // Reminders section (#19) goes here.
        case .intelligence:
            IntelligenceSection(service: service)
        case .health:
            HealthSections()
            CloudSection()
        case .data:
            PrivacySection()
            TransferSections(profile: profile)
            DeleteSection()
        }
    }
}

/// One status as a symbol and words, so color is never the only signal (#22).
struct StatusRow: View {
    enum Tone {
        case good, off, problem, waiting

        var symbol: String {
            switch self {
            case .good: "checkmark.circle.fill"
            case .off: "minus.circle"
            case .problem: "exclamationmark.triangle.fill"
            case .waiting: "clock"
            }
        }

        var color: Color {
            switch self {
            case .good: Color.brandText(\.done)
            case .off, .waiting: Color.brandText(\.subtext)
            case .problem: Color.brandText(\.alert)
            }
        }
    }

    let tone: Tone
    /// What the status is about, when the row is one of several.
    var title: LocalizedStringResource?
    let text: LocalizedStringResource

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .foregroundStyle(Color.brand(\.ink))
                }
                Text(text)
                    .foregroundStyle(title == nil ? Color.brand(\.ink) : Color.brandText(\.subtext))
            }
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: tone.symbol)
                .foregroundStyle(tone.color)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// The picker style for Settings rows. A menu's value stays on one line and gets cut off at
    /// the accessibility text sizes, so there the choices move to their own screen, where the
    /// row and every choice can wrap (#22).
    func settingsPickerStyle() -> some View {
        modifier(SettingsPickerStyle())
    }
}

private struct SettingsPickerStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        #if os(iOS)
            if dynamicTypeSize.isAccessibilitySize {
                content.pickerStyle(.navigationLink)
            } else {
                content.pickerStyle(.menu)
            }
        #else
            content
        #endif
    }
}

#Preview("iPhone") {
    let container = try! SampleData.previewContainer()  // swiftlint:disable:this force_try
    // swiftlint:disable:next force_try
    let profile = try! container.mainContext.fetch(FetchDescriptor<Profile>()).first!
    return NavigationStack {
        SettingsView(profile: profile, service: PreviewIntelligenceService())
    }
    .modelContainer(container)
}

#Preview("No profile yet") {
    // swiftlint:disable:next force_try
    let container = try! TransmuteStore.makeContainer(.inMemory)
    return NavigationStack {
        SettingsView(profile: nil, service: PreviewIntelligenceService())
    }
    .modelContainer(container)
}
