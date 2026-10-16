import Foundation

/// What to change in Spotlight after the store is saved. The apps keep the text they
/// last indexed for each workout and plan; comparing it with the text now says which items
/// to index again and which to take out.
public struct IndexChanges: Equatable, Sendable {
    /// New items, and ones whose text changed.
    public var updated: Set<UUID>
    /// Items that were indexed and are gone.
    public var removed: Set<UUID>
    /// Whether to clear the whole type and index every item again.
    public var isFullReset: Bool

    /// - Parameters:
    ///   - indexed: The text last indexed, by item. `nil` before the first index.
    ///   - current: The text each item has now.
    public init(indexed: [UUID: String]?, current: [UUID: String]) {
        let indexedText = indexed ?? [:]
        updated = Set(current.filter { indexedText[$0.key] != $0.value }.keys)
        removed = Set(indexedText.keys).subtracting(current.keys)
        isFullReset = indexed == nil || (current.isEmpty && !removed.isEmpty)
    }

    public var isEmpty: Bool {
        updated.isEmpty && removed.isEmpty
    }
}
