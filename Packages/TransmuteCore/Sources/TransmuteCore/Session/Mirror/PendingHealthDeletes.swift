import Foundation

/// Health workouts still to remove after the watch's replaced the iPhone's, and the workouts the
/// person deleted in History. Both stay in `defaults` until they're used: a failed delete or a
/// kill between linking and deleting is picked up by a later pass.
struct PendingHealthDeletes {
    struct Entry: Codable, Equatable {
        let workoutID: UUID
        /// Nil once it's been deleted along with a workout the person removed.
        let watchHealthID: UUID?
        let phoneHealthID: UUID?

        /// The names entries were stored under before the fields were renamed.
        private enum CodingKeys: String, CodingKey {
            case workoutID
            case watchHealthID = "keep"
            case phoneHealthID = "remove"
        }
    }

    let defaults: UserDefaults
    private static let entriesKey = "link.pendingHealthDeletes"
    private static let tombstonesKey = "link.deletedWorkouts"
    /// Newest tombstones kept. A tombstone only matters while a watch's Health id for that
    /// workout can still arrive, so older ones go. Losing one is safe: the watch's Health
    /// workout then stays.
    static let tombstoneLimit = 100

    /// Every key this type writes, for delete-all to clear.
    static let keys = [entriesKey, tombstonesKey]

    var entries: [Entry] {
        get { read(Self.entriesKey) }
        nonmutating set { write(newValue, Self.entriesKey) }
    }

    func add(_ entry: Entry) {
        guard !entries.contains(entry) else { return }
        entries.append(entry)
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0 == entry }
    }

    func replace(_ entry: Entry, with remaining: Entry) {
        guard remaining.watchHealthID != nil || remaining.phoneHealthID != nil else { return remove(entry) }
        entries = entries.map { $0 == entry ? remaining : $0 }
    }

    /// Workouts the person deleted in History, oldest first. The watch's Health workout for one
    /// of these has nothing left to belong to; a workout that's merely missing from the store
    /// (a fallback store, a restore in progress) isn't on this list.
    var deletedWorkouts: [UUID] {
        read(Self.tombstonesKey)
    }

    func markDeleted(_ workoutID: UUID) {
        var deleted = deletedWorkouts.filter { $0 != workoutID }
        deleted.append(workoutID)
        write(Array(deleted.suffix(Self.tombstoneLimit)), Self.tombstonesKey)
    }

    func wasDeleted(_ workoutID: UUID) -> Bool {
        deletedWorkouts.contains(workoutID)
    }

    func forgetDeleted(_ workoutID: UUID) {
        guard wasDeleted(workoutID) else { return }
        write(deletedWorkouts.filter { $0 != workoutID }, Self.tombstonesKey)
    }

    private func read<Value: Decodable>(_ key: String) -> [Value] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([Value].self, from: $0) } ?? []
    }

    private func write<Value: Encodable>(_ values: [Value], _ key: String) {
        defaults.set(try? JSONEncoder().encode(values), forKey: key)
    }
}
