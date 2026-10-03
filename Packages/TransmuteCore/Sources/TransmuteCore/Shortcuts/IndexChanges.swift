import Foundation

/// What to change in Spotlight after the store is saved (#19). The apps keep the text they
/// last indexed for each workout and plan; comparing it with the text now says which items
/// to index again and which to take out.
public struct IndexChanges: Equatable, Sendable {
    /// New items, and ones whose text changed.
    public var updated: Set<UUID>
    /// Items that were indexed and are gone.
    public var removed: Set<UUID>

    /// - Parameters:
    ///   - indexed: The text last indexed, by item.
    ///   - current: The text each item has now.
    public init(indexed: [UUID: String], current: [UUID: String]) {
        updated = Set(current.filter { indexed[$0.key] != $0.value }.keys)
        removed = Set(indexed.keys).subtracting(current.keys)
    }

    public var isEmpty: Bool {
        updated.isEmpty && removed.isEmpty
    }
}
