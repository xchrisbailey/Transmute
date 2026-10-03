import Foundation
import SwiftData
import TransmuteCore
import TransmuteIntelligence
import TransmuteLogUI
import TransmuteUI
import UserNotifications

/// How delete-all ended, kept in `UserDefaults` so the report outlives the screen that asked
/// for it: deleting the profile sends the app back to onboarding, which shows `ErasureNotice`.
public enum ErasureOutcome: String, Sendable {
    /// Gone from this device and from iCloud.
    case everywhere
    /// Gone from this device; this build doesn't sync, so there was nothing in iCloud to delete.
    case localOnly
    /// Gone from this device, but iCloud couldn't be reached.
    case cloudFailed

    /// Where the outcome waits until the person has seen it.
    public static let defaultsKey = "erasure.outcome"

    init(_ erasure: CloudErasure) {
        switch erasure {
        case .deleted: self = .everywhere
        case .notSyncing: self = .localOnly
        case .failed: self = .cloudFailed
        }
    }

    var message: LocalizedStringResource {
        switch self {
        case .everywhere: SettingsDataCopy.erasedEverywhere
        case .localOnly: SettingsDataCopy.erasedLocalOnly
        case .cloudFailed: SettingsDataCopy.erasedCloudFailed
        }
    }
}

/// Transmute's own keys in `UserDefaults`, which delete-all puts back to their defaults (#18).
/// The store holds everything else.
enum DefaultsReset {
    /// The tab and layout last shown, the appearance and the AI route.
    static let keys = [Appearance.defaultsKey, IntelligenceSettings.routeKey, "rootTab", "planGrid"]
    /// Reminder settings (#19) all start with this.
    static let prefixes = ["reminders."]

    static func run(in defaults: UserDefaults = .standard) {
        let stored = defaults.dictionaryRepresentation().keys
        for key in keys + stored.filter({ key in prefixes.contains { key.hasPrefix($0) } }) {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Delete-all (#18): everything in the store, here and in iCloud, and what the app keeps
/// outside it.
@MainActor
enum DataEraser {
    /// Runs every step in order and returns how the iCloud step went, which is also recorded
    /// for `ErasureNotice`. Throws, with the store untouched, if the local delete fails.
    @discardableResult
    static func eraseEverything(
        in container: ModelContainer, link: SessionLink?, defaults: UserDefaults = .standard,
        clearsNotifications: Bool = true
    ) async throws -> ErasureOutcome {
        // A workout in progress goes with the rest: end its Live Activity and tell the watch.
        await SessionTeardown.run(link: link)
        let context = container.mainContext
        do {
            try DataTransfer.deleteAll(in: context)
        } catch {
            context.rollback()
            throw error
        }
        DefaultsReset.run(in: defaults)
        if clearsNotifications {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }
        let outcome = ErasureOutcome(await DataTransfer.deleteCloudRecords(for: container))
        defaults.set(outcome.rawValue, forKey: ErasureOutcome.defaultsKey)
        return outcome
    }

    /// Tries the iCloud step again after it failed.
    static func retryCloud(for container: ModelContainer, defaults: UserDefaults = .standard) async {
        let outcome = ErasureOutcome(await DataTransfer.deleteCloudRecords(for: container))
        defaults.set(outcome.rawValue, forKey: ErasureOutcome.defaultsKey)
    }
}
