import SwiftData
import SwiftUI
import TransmuteCore
import TransmuteUI

extension HealthAccessStatus.Write {
    var tone: StatusRow.Tone {
        switch self {
        case .allowed: .good
        case .denied: .problem
        case .notAsked: .off
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .allowed: SettingsStatusCopy.writeAllowed
        case .denied: SettingsStatusCopy.writeDenied
        case .notAsked: SettingsStatusCopy.notAsked
        }
    }
}

extension HealthAccessStatus.Read {
    /// Being asked isn't the same as saying yes, so it never gets the green tick.
    var tone: StatusRow.Tone {
        switch self {
        case .asked: .waiting
        case .notAsked, .unknown: .off
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .asked: SettingsStatusCopy.readAsked
        case .notAsked: SettingsStatusCopy.notAsked
        case .unknown: SettingsStatusCopy.readUnknown
        }
    }
}

extension HealthWriteKind {
    var label: LocalizedStringResource {
        switch self {
        case .workouts: SettingsStatusCopy.writeWorkouts
        case .bodyweight: SettingsStatusCopy.writeBodyweight
        case .activeEnergy: SettingsStatusCopy.writeActiveEnergy
        case .heartRate: SettingsStatusCopy.writeHeartRate
        }
    }
}

extension HealthAccessScope {
    /// What the group reads, in plain words.
    var readLabel: LocalizedStringResource {
        switch self {
        case .profile: SettingsStatusCopy.readProfile
        case .trainingLoad: SettingsStatusCopy.readTrainingLoad
        case .workouts: SettingsStatusCopy.readWorkouts
        }
    }
}

/// Health access (#18), as far as Health lets an app know it: whether saving each kind of data
/// is allowed, and whether the person has been asked about reading. On the Mac, which has no
/// Health, it says where the data comes from instead.
struct HealthSections: View {
    @Environment(\.health) private var health
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = HealthAccessStatus()

    var body: some View {
        if health.isAvailable {
            Section {
                ForEach(HealthWriteKind.allCases, id: \.self) { kind in
                    let write = status.writes[kind] ?? .notAsked
                    StatusRow(tone: write.tone, title: kind.label, text: write.label)
                }
            } header: {
                Text(SettingsStatusCopy.healthSaving)
            }
            Section {
                ForEach(HealthAccessScope.allCases, id: \.self) { scope in
                    let read = status.reads[scope] ?? .unknown
                    StatusRow(tone: read.tone, title: scope.readLabel, text: read.label)
                }
            } header: {
                Text(SettingsStatusCopy.healthReading)
            } footer: {
                Text(SettingsStatusCopy.readNote)
            }
            // Coming back from the Health app, the answers may have changed.
            .task(id: scenePhase) { status = await health.accessStatus() }
            Section {
                Button {
                    if let url = URL(string: "x-apple-health://") { openURL(url) }
                } label: {
                    Text(SettingsStatusCopy.openHealth)
                }
            } footer: {
                Text(SettingsStatusCopy.healthChangeNote)
            }
        } else {
            Section {
                #if os(macOS)
                    StatusRow(tone: .off, text: SettingsStatusCopy.healthOnMac)
                #else
                    StatusRow(tone: .off, text: SettingsStatusCopy.healthUnavailable)
                #endif
            } header: {
                Text(SettingsStatusCopy.health)
            }
        }
    }
}

extension CloudSyncStatus {
    var tone: StatusRow.Tone {
        switch self {
        case .available: .good
        case .notSyncing, .signedOut: .off
        case .restricted, .unknown: .problem
        case .temporarilyUnavailable: .waiting
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .available: SettingsStatusCopy.cloudAvailable
        case .notSyncing: SettingsStatusCopy.cloudNotSyncing
        case .signedOut: SettingsStatusCopy.cloudSignedOut
        case .restricted: SettingsStatusCopy.cloudRestricted
        case .temporarilyUnavailable: SettingsStatusCopy.cloudTemporarilyUnavailable
        case .unknown: SettingsStatusCopy.cloudUnknown
        }
    }
}

/// Whether this copy of Transmute syncs with iCloud, and if not, why (#18).
struct CloudSection: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: CloudSyncStatus?

    var body: some View {
        Section {
            if let status {
                StatusRow(tone: status.tone, text: status.message)
            } else {
                StatusRow(tone: .waiting, text: SettingsStatusCopy.cloudChecking)
            }
        } header: {
            Text(SettingsStatusCopy.cloud)
        }
        .task(id: scenePhase) { status = await TransmuteStore.cloudSyncStatus(of: context.container) }
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! TransmuteStore.makeContainer(.inMemory)
    return Form {
        HealthSections()
        CloudSection()
    }
    .modelContainer(container)
}
