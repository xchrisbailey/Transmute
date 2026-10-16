import SwiftUI
import TransmuteCore
import TransmuteUI

public struct ReminderSettingsSection: View {
    @State private var settings: ReminderSettings
    @State private var permission: ReminderPermission?
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    private let defaults: UserDefaults
    /// Set in previews, which show a permission state without asking the system.
    private let fixedPermission: ReminderPermission?

    public init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, permission: nil)
    }

    init(defaults: UserDefaults, permission: ReminderPermission?) {
        self.defaults = defaults
        fixedPermission = permission
        _settings = State(initialValue: .load(from: defaults))
        _permission = State(initialValue: permission)
    }

    public var body: some View {
        Section {
            Toggle(isOn: binding(\.remindsOnTrainingDays, asks: true)) {
                Text(ReminderCopy.trainingDay)
                Text(ReminderCopy.trainingDayDetail)
            }
            .task { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                // Back from the system's settings, where permission may have changed.
                guard phase == .active else { return }
                Task { await refresh() }
            }
            if settings.remindsOnTrainingDays {
                DatePicker(selection: time, displayedComponents: .hourAndMinute) {
                    Text(ReminderCopy.time)
                }
            }
            Toggle(isOn: binding(\.nudgesAfterMissedDay, asks: true)) {
                Text(ReminderCopy.missedDay)
                Text(ReminderCopy.missedDayDetail)
            }
            if settings.isOn, permission == .denied {
                deniedNotice
            }
        } header: {
            Text(ReminderCopy.title)
        } footer: {
            Text(ReminderCopy.footer)
        }
    }

    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(ReminderCopy.denied)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "bell.slash")
                    .foregroundStyle(Color.brandText(\.subtext))
            }
            if let settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Text(ReminderCopy.openSettings)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var settingsURL: URL? {
        #if os(iOS)
            URL(string: UIApplication.openNotificationSettingsURLString)
        #else
            URL(
                string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id="
                    + (Bundle.main.bundleIdentifier ?? ""))
        #endif
    }

    private var time: Binding<Date> {
        Binding {
            settings.trainingDayTime()
        } set: { date in
            settings.setTrainingDayTime(date)
            saveAndReschedule(requestingPermission: false)
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ReminderSettings, Bool>, asks: Bool) -> Binding<Bool> {
        Binding {
            settings[keyPath: keyPath]
        } set: { isOn in
            settings[keyPath: keyPath] = isOn
            saveAndReschedule(requestingPermission: asks && isOn)
        }
    }

    /// `TrainingReminders` reschedules when the saved defaults change. When a reminder was just
    /// turned on, permission is settled first, so the reminders are scheduled with the answer known.
    private func saveAndReschedule(requestingPermission: Bool) {
        guard requestingPermission, fixedPermission == nil else {
            settings.save(to: defaults)
            return
        }
        Task {
            permission = await ReminderScheduler.requestPermission()
            settings.save(to: defaults)
        }
    }

    private func refresh() async {
        guard fixedPermission == nil else { return }
        permission = await ReminderScheduler.permission()
    }
}

#Preview {
    let defaults = UserDefaults(suiteName: "preview.reminders") ?? .standard
    ReminderSettings(remindsOnTrainingDays: true, nudgesAfterMissedDay: true).save(to: defaults)
    return Form {
        ReminderSettingsSection(defaults: defaults, permission: .denied)
    }
    .formStyle(.grouped)
}
