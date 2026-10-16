import Foundation

/// Health workouts still to remove after the watch's replaced the iPhone's. They stay in
/// `defaults` until Health has done it, so a failed delete or a kill between linking and deleting
/// is picked up by a later pass.
struct PendingHealthDeletes {
    struct Entry: Codable, Equatable {
        let workoutID: UUID
        /// The Health workout the Transmute workout ends up linked to.
        let keep: UUID
        /// The iPhone's own Health workout, which `keep` replaces.
        let remove: UUID?
    }

    let defaults: UserDefaults
    private static let key = "link.pendingHealthDeletes"

    var entries: [Entry] {
        get {
            defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Entry].self, from: $0) } ?? []
        }
        nonmutating set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.key) }
    }

    func add(_ entry: Entry) {
        guard !entries.contains(entry) else { return }
        entries.append(entry)
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0 == entry }
    }
}
