import Foundation

/// Asks the log to show one finished workout. `HistoryView` and `LogTableView` take it and
/// clear it from the binding they were given.
public struct WorkoutOpenRequest: Equatable, Sendable {
    public let workoutID: UUID

    public init(workoutID: UUID) {
        self.workoutID = workoutID
    }
}

/// Asks Today to begin a workout, or go back into the running one. `TodayView` takes it and
/// clears it from the binding it was given.
public struct WorkoutBeginRequest: Equatable, Sendable {
    public init() {}
}
