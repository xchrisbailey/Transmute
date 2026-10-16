import TransmuteCore

/// How Today stands towards the running workout, if any, on a given device.
enum RunningWorkoutState: Equatable {
    case none
    /// A session is already showing, so opening one again would be a second.
    case onScreen
    /// Another device started the workout and keeps it; this one mirrors it.
    case ownedElsewhere(Workout)
    case resumable(Workout)

    init(running: Workout?, device: SessionDevice, session: Workout?) {
        guard let running else {
            self = .none
            return
        }
        if session != nil {
            self = .onScreen
        } else if running.isOwned(by: device) {
            self = .resumable(running)
        } else {
            self = .ownedElsewhere(running)
        }
    }
}
