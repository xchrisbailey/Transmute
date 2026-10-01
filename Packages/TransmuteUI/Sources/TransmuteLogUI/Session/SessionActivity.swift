import Foundation

#if os(iOS)
    import ActivityKit
    import TransmuteUI
#endif

#if os(iOS)
    /// Starts, updates and ends the workout's Live Activity. Does nothing where Live
    /// Activities are off or unsupported.
    @MainActor
    final class SessionActivity {
        func update(title: String, state: SessionActivityAttributes.ContentState) {
            let content = ActivityContent(state: state, staleDate: state.restEndsAt)
            if !Activity<SessionActivityAttributes>.activities.isEmpty {
                Task {
                    for activity in Activity<SessionActivityAttributes>.activities {
                        await activity.update(content)
                    }
                }
                return
            }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try? Activity.request(attributes: SessionActivityAttributes(workoutTitle: title), content: content)
        }

        func end() {
            Task {
                for activity in Activity<SessionActivityAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
#else
    /// No Live Activities on the Mac.
    @MainActor
    final class SessionActivity {
        func update(title: String, state: SessionActivityAttributes.ContentState) {}
        func end() {}
    }

    /// Stands in for the iPhone's Live Activity state so the session screen builds on the Mac.
    enum SessionActivityAttributes {
        struct ContentState: Hashable {
            var exercise: String
            var setNumber: Int
            var setCount: Int
            var restEndsAt: Date?
            var restSeconds: Double?
        }
    }
#endif
