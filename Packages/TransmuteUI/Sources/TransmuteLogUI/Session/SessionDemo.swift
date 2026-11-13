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

/// The demonstration being viewed, and nothing else about the workout. Reporting reads this.
struct ViewedDemo: Equatable {
    let exerciseID: String
    let exerciseName: String
    let equipment: Set<Equipment>
    let videoID: String
}

/// Viewing state has no model context, timer, session-link or workout-writing effects.
@MainActor @Observable
final class SessionDemo: Identifiable {
    enum Phase {
        case loading, ready, playing, paused, unavailable, stoppedForLink
        /// Nothing to play: written cues only, or an equipment choice with no reviewed match.
        case noVideo
    }

    /// What the report screen says happened. Opening GitHub or copying is never "submitted".
    enum ReportOutcome { case githubOpened, githubFailed, copied }

    /// What the logging header can offer for an exercise. Nil offers nothing, never invented help.
    enum Guidance { case demo, cues }

    let id = UUID()
    private let workout: Workout
    private let library: ExerciseLibrary
    let player: any DemoPlayer
    private let openLink: (URL, @escaping (Bool) -> Void) -> Void
    private let appVersion: String?
    private let copy: (String) -> Void
    private(set) var association: ExerciseDemo?
    private(set) var name = ""
    private(set) var cues: [String] = []
    private(set) var choices: [DemoChoice] = []
    /// The equipment whose demonstration is on view. This is viewing state, never the equipment used.
    private(set) var selectedEquipment: Set<Equipment>?
    private(set) var phase: Phase = .loading
    private(set) var attempt = UUID()
    private(set) var isPresented = false
    /// A report being prepared for the demonstration on view. The person submits it, if at all, in GitHub.
    private(set) var report: DemoReport?
    private(set) var reportOutcome: ReportOutcome?
    private var reportHandoff: UUID?
    private var sceneActive = true
    private var interrupted = false

    init(
        workout: Workout, library: ExerciseLibrary, player: any DemoPlayer,
        openLink: @escaping (URL, @escaping (Bool) -> Void) -> Void = { _, completion in completion(false) },
        appVersion: String? = DataTransfer.bundleVersion, copy: @escaping (String) -> Void = { _ in }
    ) {
        self.workout = workout
        self.library = library
        self.player = player
        self.openLink = openLink
        self.appVersion = appVersion
        self.copy = copy
        player.onEvent = { [weak self] event, attempt in
            self?.receive(event, attempt: attempt)
        }
    }

    /// Guidance belongs to the iPhone's own running workout, never one another device owns.
    static func canView(_ workout: Workout) -> Bool {
        workout.endedAt == nil && (workout.startedOn == nil || workout.startedOn == .phone)
    }

    static func guidance(for exerciseID: String, library: ExerciseLibrary) -> Guidance? {
        if !library.demoChoices(exerciseID: exerciseID).isEmpty { return .demo }
        return suppliedCues(of: exerciseID, library: library).isEmpty ? nil : .cues
    }

    private static func suppliedCues(of exerciseID: String, library: ExerciseLibrary) -> [String] {
        (library.exercise(id: exerciseID)?.cues ?? []).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// The reviewed demonstration on view, or nil while there is none to show.
    var viewed: ViewedDemo? {
        guard isPresented, let association else { return nil }
        return ViewedDemo(
            exerciseID: association.exerciseID, exerciseName: name, equipment: association.equipment,
            videoID: association.videoID)
    }

    @discardableResult
    func open(_ exercise: LoggedExercise) -> Bool {
        guard !isPresented, Self.canView(workout),
            workout.orderedExercises.contains(where: { $0 === exercise }),
            let content = library.exercise(id: exercise.exerciseID),
            Self.guidance(for: exercise.exerciseID, library: library) != nil
        else { return false }
        name = content.name
        cues = Self.suppliedCues(of: exercise.exerciseID, library: library)
        choices = library.demoChoices(exerciseID: exercise.exerciseID)
        isPresented = true
        if let first = choices.first(where: { $0.demo != nil }) {
            show(first)
        } else {
            phase = .noVideo
        }
        return true
    }

    /// Chooses which equipment's demonstration to view. The workout is not consulted or changed.
    func select(_ equipment: Set<Equipment>) {
        guard isPresented, report == nil, selectedEquipment != equipment,
            let choice = choices.first(where: { $0.equipment == equipment })
        else { return }
        show(choice)
    }

    private func show(_ choice: DemoChoice) {
        // The previous video, if any, is stopped before anything replaces it.
        if association != nil { player.stop() }
        selectedEquipment = choice.equipment
        association = choice.demo
        attempt = UUID()
        guard choice.demo != nil else {
            phase = .noVideo
            return
        }
        if sceneActive, !interrupted {
            load()
        } else {
            phase = .paused
        }
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
        report = nil
        reportOutcome = nil
        reportHandoff = nil
        if association != nil { player.stop() }
    }

    /// Starts a report about exactly the demonstration on view, stopping its playback first.
    func beginReport() {
        guard report == nil, let viewed else { return }
        report = DemoReport(demo: viewed, appVersion: appVersion)
        reportOutcome = nil
        reportHandoff = nil
        // Failure and link states keep their own recovery, so closing the report brings Retry back.
        if phase != .unavailable, phase != .stoppedForLink {
            attempt = UUID()
            phase = .paused
        }
        player.stop()
    }

    func setReportDescription(_ text: String) {
        guard report != nil else { return }
        report?.setDescription(text)
        reportOutcome = nil
    }

    /// Hands the prepared report to GitHub for the person to review and submit there.
    func openReport() {
        guard let report else { return }
        let handoff = UUID()
        reportHandoff = handoff
        openLink(report.url) { [weak self] opened in
            guard let self, self.reportHandoff == handoff else { return }
            self.reportOutcome = opened ? .githubOpened : .githubFailed
        }
    }

    func copyReport() {
        guard let report else { return }
        reportHandoff = nil
        copy(report.copyText)
        reportOutcome = .copied
    }

    /// Returns to the guide. Playback stays stopped until the person asks for it again.
    func closeReport() {
        guard report != nil else { return }
        report = nil
        reportOutcome = nil
        reportHandoff = nil
        if isPresented, phase == .paused, sceneActive, !interrupted { load() }
    }

    private func updateActivity() {
        guard isPresented, report == nil, association != nil, phase != .unavailable, phase != .stoppedForLink else {
            return
        }
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
