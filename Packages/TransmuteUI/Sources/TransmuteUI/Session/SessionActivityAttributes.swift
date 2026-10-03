#if os(iOS)
    import ActivityKit
    import Foundation

    /// The Live Activity and Dynamic Island for a workout in progress (#11): the current
    /// exercise and set, and the rest countdown. Shared by the app, which starts and updates
    /// it, and the widget extension, which draws it.
    public struct SessionActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable, Sendable {
            public var exercise: String
            /// 1-based.
            public var setNumber: Int
            public var setCount: Int
            /// When the running rest ends, or `nil` between rests.
            public var restEndsAt: Date?
            /// The rest's full length, for the ring.
            public var restSeconds: Double?

            public init(exercise: String, setNumber: Int, setCount: Int, restEndsAt: Date?, restSeconds: Double?) {
                self.exercise = exercise
                self.setNumber = setNumber
                self.setCount = setCount
                self.restEndsAt = restEndsAt
                self.restSeconds = restSeconds
            }

            /// The rest's whole span, for `Text(timerInterval:)` and `ProgressView(timerInterval:)`.
            public var restInterval: ClosedRange<Date>? {
                guard let restEndsAt, let restSeconds, restEndsAt > .now else { return nil }
                return restEndsAt.addingTimeInterval(-restSeconds)...restEndsAt
            }
        }

        public var workoutTitle: String

        public init(workoutTitle: String) {
            self.workoutTitle = workoutTitle
        }
    }
#endif
