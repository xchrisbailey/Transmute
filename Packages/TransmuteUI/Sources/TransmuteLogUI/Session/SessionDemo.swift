import Foundation
import Observation
import TransmuteCore

enum DemoPlayerEvent {
    case ready, playing, paused, failed
    case mainFrameLink(URL)
    case newWindowLink(URL)
}

@MainActor
protocol DemoPlayer: AnyObject {
    var onEvent: ((DemoPlayerEvent, UUID) -> Void)? { get set }
    func load(videoID: String, attempt: UUID)
    func play()
    /// Pauses and retires this player so returning cannot resume a suspended web process.
    func pause()
    func stop()
}

/// Viewing state has no model context, timer, session-link or workout-writing effects.
@MainActor @Observable
final class SessionDemo: Identifiable {
    enum Phase { case loading, ready, playing, paused, unavailable, stoppedForLink }

    let id = UUID()
    private let workout: Workout
    private let library: ExerciseLibrary
    let player: any DemoPlayer
    private let openLink: (URL, @escaping (Bool) -> Void) -> Void
    private(set) var association: ExerciseDemo?
    private(set) var name = ""
    private(set) var cues: [String] = []
    private(set) var phase: Phase = .loading
    private(set) var attempt = UUID()
    private(set) var isPresented = false
    private var sceneActive = true
    private var interrupted = false

    init(
        workout: Workout, library: ExerciseLibrary, player: any DemoPlayer,
        openLink: @escaping (URL, @escaping (Bool) -> Void) -> Void = { _, completion in completion(false) }
    ) {
        self.workout = workout
        self.library = library
        self.player = player
        self.openLink = openLink
        player.onEvent = { [weak self] event, attempt in
            self?.receive(event, attempt: attempt)
        }
    }

    @discardableResult
    func open(_ exercise: LoggedExercise) -> Bool {
        guard !isPresented, workout.endedAt == nil, workout.startedOn == nil || workout.startedOn == .phone,
            workout.orderedExercises.contains(where: { $0 === exercise }),
            let association = library.demo(exerciseID: exercise.exerciseID),
            let content = library.exercise(id: exercise.exerciseID)
        else { return false }
        self.association = association
        name = content.name
        cues = content.cues
        isPresented = true
        load()
        return true
    }

    func play() {
        guard isPresented, sceneActive, !interrupted, phase == .ready || phase == .paused else { return }
        player.play()
    }

    func retry() {
        guard isPresented, sceneActive, !interrupted, phase == .unavailable || phase == .stoppedForLink else { return }
        load()
    }

    func setSceneActive(_ active: Bool) {
        guard sceneActive != active else { return }
        sceneActive = active
        updateActivity()
    }

    func setInterrupted(_ value: Bool) {
        guard interrupted != value else { return }
        interrupted = value
        updateActivity()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        attempt = UUID()
        player.stop()
    }

    private func updateActivity() {
        guard isPresented, phase != .unavailable, phase != .stoppedForLink else { return }
        if !sceneActive || interrupted {
            attempt = UUID()
            phase = .paused
            player.pause()
        } else {
            load()
        }
    }

    private func load() {
        guard let association else { return }
        attempt = UUID()
        phase = .loading
        player.load(videoID: association.videoID, attempt: attempt)
    }

    private func receive(_ event: DemoPlayerEvent, attempt: UUID) {
        guard isPresented, self.attempt == attempt, sceneActive, !interrupted, phase != .unavailable else { return }
        switch event {
        case .ready: phase = .ready
        case .playing: phase = .playing
        case .paused: phase = .paused
        case .failed:
            phase = .unavailable
            player.stop()
        case .mainFrameLink(let url), .newWindowLink(let url):
            handOff(url)
        }
    }

    private func handOff(_ url: URL) {
        guard url.scheme == "https" else { return }
        attempt = UUID()
        let handoffAttempt = attempt
        phase = .stoppedForLink
        player.stop()
        // An accepted handoff need not change scenes, and a rejected one must not
        // reload media. Both leave recovery under the person's explicit control.
        openLink(url) { [weak self] opened in
            guard let self, self.isPresented, self.attempt == handoffAttempt, self.phase == .stoppedForLink else {
                return
            }
            if !opened { self.phase = .unavailable }
        }
    }
}
