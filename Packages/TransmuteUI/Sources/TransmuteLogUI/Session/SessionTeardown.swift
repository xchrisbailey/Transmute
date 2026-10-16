import TransmuteCore

/// Ends what a running workout keeps outside the store: its Live Activity and the other
/// device's copy of the session. For delete-all, which removes the workout itself and
/// clears every pending notification, the rest alert included.
public enum SessionTeardown {
    /// Call it before the workouts are deleted, while the link still knows which one it owns.
    @MainActor
    public static func endActiveWorkout(link: SessionLink?) async {
        SessionActivity().end()
        link?.discarded()
        await link?.live.discard()
    }
}
