import SwiftUI
import TransmuteIntelligence
import TransmutePlanUI
import TransmuteUI

/// Apple Intelligence (#18): whether it's ready, where plans may be made, and what leaves the
/// device. There's no switch for AI itself, since plans need it.
struct IntelligenceSection: View {
    @State private var status: IntelligenceStatus
    @AppStorage(IntelligenceSettings.routeKey) private var route = ModelRoute.onDeviceOnly
    @Environment(\.openURL) private var openURL

    init(service: any IntelligenceService) {
        _status = State(initialValue: IntelligenceStatus(service: service))
    }

    var body: some View {
        Section {
            if status.availability.canGenerate {
                StatusRow(tone: .good, text: SettingsStatusCopy.aiReady)
            } else {
                IntelligenceNotice(availability: status.availability)
            }
            // The notice has its own button when Apple Intelligence is turned off.
            if status.availability != .turnedOff, let settingsURL {
                Button {
                    openURL(settingsURL)
                } label: {
                    Text(SettingsStatusCopy.aiOpenSettings)
                }
            }
        } header: {
            Text(SettingsScreenCopy.paneIntelligence)
        } footer: {
            Text(SettingsStatusCopy.aiAlwaysOn)
        }
        .task { await status.watch() }
        Section {
            Toggle(isOn: allowsCloud) {
                Text(SettingsStatusCopy.allowCloud)
            }
            .tint(Color.brand(\.magic))
        } footer: {
            Text(route == .allowPrivateCloudCompute ? SettingsStatusCopy.cloudOn : SettingsStatusCopy.cloudOff)
        }
    }

    private var allowsCloud: Binding<Bool> {
        Binding {
            route == .allowPrivateCloudCompute
        } set: {
            route = $0 ? .allowPrivateCloudCompute : .onDeviceOnly
        }
    }

    /// The same places `IntelligenceNotice` opens.
    private var settingsURL: URL? {
        #if os(iOS)
            URL(string: UIApplication.openSettingsURLString)
        #else
            URL(string: "x-apple.systempreferences:")
        #endif
    }
}

#Preview {
    Form {
        IntelligenceSection(service: PreviewIntelligenceService())
    }
}
