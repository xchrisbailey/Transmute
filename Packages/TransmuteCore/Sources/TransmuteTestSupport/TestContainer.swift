import SwiftData
import TransmuteCore

extension TransmuteStore {
    /// An in-memory container for one test, with autosave off.
    ///
    /// SwiftData arms a timer on the main run loop at a context's first unsaved change. Swift
    /// Testing releases a suite's instance, and so its container, on another thread, and a
    /// timer that fires while the container is going or gone traps in SwiftData. A test saves
    /// when it means to, so it has no use for the timer.
    @MainActor
    public static func makeTestContainer() throws -> ModelContainer {
        let container = try makeContainer(.inMemory)
        container.mainContext.autosaveEnabled = false
        return container
    }
}
