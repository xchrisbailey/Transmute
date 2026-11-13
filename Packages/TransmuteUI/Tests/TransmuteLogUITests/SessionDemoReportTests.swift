import Foundation
import SwiftData
import Testing
import TransmuteCore
import TransmuteTestSupport

@testable import TransmuteLogUI

@MainActor
final class ClipboardSpy {
    var copied: [String] = []
    func copy(_ text: String) { copied.append(text) }
}

@MainActor
private struct ReportFixture {
    let workout: Workout
    let exercise: LoggedExercise
    let library: ExerciseLibrary
    let player: DemoPlayerSpy
    let link: DemoLinkSpy
    let clipboard: ClipboardSpy
    let demo: SessionDemo
}

@MainActor
struct SessionDemoReportTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func fixture(
        in context: ModelContext, demos: [ExerciseDemo]? = nil, sets: Int = 3
    ) throws -> ReportFixture {
        let goblet = try #require(ExerciseLibrary.bundled.exercise(id: "goblet-squat"))
        let library = ExerciseLibrary(
            catalogVersion: 1, exercises: [goblet],
            demos: demos ?? [
                synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001"),
                synthetic("goblet-squat", [.kettlebell], video: "TESTONLY002"),
            ])
        let workout = WorkoutSession.startAdHoc(title: "Private morning session", at: now, in: context)
        let exercise = WorkoutSession.add(goblet, to: workout, sets: sets)
        exercise.notes = "knee felt odd"
        let first = exercise.orderedSets[0]
        first.reps = 8
        first.restSeconds = 60
        WorkoutSession.complete(first, in: workout, at: now)
        let current = try #require(WorkoutSession.currentSet(of: workout))
        current.reps = 7
        current.weightKg = 12.5
        try context.save()
        let player = DemoPlayerSpy()
        let link = DemoLinkSpy()
        let clipboard = ClipboardSpy()
        let demo = SessionDemo(
            workout: workout, library: library, player: player, openLink: link.open, appVersion: "0.3.0",
            copy: clipboard.copy)
        return ReportFixture(
            workout: workout, exercise: exercise, library: library, player: player, link: link,
            clipboard: clipboard, demo: demo)
    }

    @Test func reportNamesTheSelectedEquipmentVideoAndNothingPrivate() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let run = try fixture(in: context)
        let before = SessionSnapshot(run.workout, library: run.library)
        #expect(run.demo.open(run.exercise))
        #expect(run.demo.report == nil, "Opening the guide prepares nothing")

        run.demo.beginReport()
        #expect(run.demo.report?.demo.videoID == "TESTONLY001")
        run.demo.closeReport()
        run.demo.select([.kettlebell])
        run.demo.beginReport()
        let report = try #require(run.demo.report)
        #expect(report.demo.equipment == [.kettlebell] && report.demo.videoID == "TESTONLY002")
        #expect(report.body.contains("- Demo equipment: kettlebell"))
        #expect(report.body.contains("watch?v=TESTONLY002") && !report.body.contains("TESTONLY001"))
        for secret in ["Private morning", "knee felt", "12.5", "reps", "2026", "Health"] {
            #expect(!report.copyText.contains(secret), "\(secret)")
        }
        #expect(report.body.contains("- App version: 0.3.0"))
        #expect(!context.hasChanges)
        #expect(SessionSnapshot(run.workout, library: run.library) == before)
    }

    @Test func nothingLeavesTheAppUntilThePersonChoosesTo() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        #expect(run.demo.open(run.exercise))
        run.demo.beginReport()
        run.demo.setReportDescription("Wrong move & more\nsecond line")
        #expect(run.demo.reportOutcome == nil)
        #expect(run.link.urls.isEmpty && run.clipboard.copied.isEmpty)

        let report = try #require(run.demo.report)
        run.demo.openReport()
        #expect(run.link.urls == [report.url])
        run.link.complete(true)
        #expect(run.demo.reportOutcome == .githubOpened)
        #expect(run.demo.report == report, "Opening GitHub keeps the report on screen")
        run.demo.copyReport()
        #expect(run.clipboard.copied == [report.copyText])
        #expect(run.demo.reportOutcome == .copied)
        #expect(run.link.urls.count == 1)
    }

    @Test func aFailedHandoffKeepsTheReportAndCopyStillWorks() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        #expect(run.demo.open(run.exercise))
        run.demo.beginReport()
        run.demo.setReportDescription("Keep this text")
        run.demo.openReport()
        run.link.complete(false)
        #expect(run.demo.reportOutcome == .githubFailed)
        #expect(run.demo.report?.description == "Keep this text")
        run.demo.copyReport()
        #expect(run.clipboard.copied.count == 1 && run.clipboard.copied[0].contains("Keep this text"))
        #expect(run.demo.reportOutcome == .copied)
        run.demo.setReportDescription("Edited after")
        #expect(run.demo.reportOutcome == nil, "A stale notice never describes edited text")
        run.demo.openReport()
        run.link.complete(true)
        #expect(run.link.urls.count == 2 && run.link.urls[1] == run.demo.report?.url)
    }

    @Test func everyCopyAndFailedOpenGivesFreshFeedbackAndEditsRetireLateResults() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        #expect(run.demo.open(run.exercise))
        run.demo.beginReport()
        run.demo.copyReport()
        run.demo.copyReport()
        #expect(run.demo.reportOutcome == .copied && run.demo.reportFeedback == 2)
        run.demo.openReport()
        run.link.complete(false)
        run.demo.openReport()
        run.link.complete(false)
        #expect(run.demo.reportOutcome == .githubFailed && run.demo.reportFeedback == 4)

        // An open that finishes after the text was edited cannot describe the edited text.
        run.demo.openReport()
        run.demo.setReportDescription("Edited while GitHub was opening")
        run.link.complete(true)
        #expect(run.demo.reportOutcome == nil && run.demo.reportFeedback == 4)
    }

    @Test func cancellingLeavesPlaybackStoppedAndLoggingUntouched() throws {
        let container = try TransmuteStore.makeTestContainer()
        let context = container.mainContext
        let run = try fixture(in: context)
        let before = SessionSnapshot(run.workout, library: run.library)
        let current = try #require(WorkoutSession.currentSet(of: run.workout))
        #expect(run.demo.open(run.exercise))
        let attempt = run.demo.attempt
        run.player.send(.ready, attempt: attempt)
        run.demo.play()
        run.player.send(.playing, attempt: attempt)
        run.demo.beginReport()
        #expect(run.player.commands == ["load:TESTONLY001", "play", "stop"])
        run.player.send(.playing, attempt: attempt)
        #expect(run.demo.phase == .paused, "The stopped video cannot resume itself")

        // Leaving for the browser and returning does not reload or restart media behind the report.
        run.demo.setSceneActive(false)
        run.demo.setSceneActive(true)
        run.demo.setInterrupted(true)
        run.demo.setInterrupted(false)
        run.demo.select([.kettlebell])
        #expect(run.player.commands == ["load:TESTONLY001", "play", "stop"])
        #expect(run.demo.report?.demo.equipment == [.dumbbell], "Equipment cannot change under a report")

        run.demo.closeReport()
        #expect(run.demo.report == nil && run.demo.reportOutcome == nil && run.demo.isPresented)
        #expect(run.demo.phase == .loading && run.player.commands.last == "load:TESTONLY001")
        run.player.send(.ready, attempt: run.demo.attempt)
        #expect(run.demo.phase == .ready)
        #expect(run.player.commands.filter { $0 == "play" }.count == 1, "Return waits for an explicit Play")

        #expect(!context.hasChanges && SessionSnapshot(run.workout, library: run.library) == before)
        #expect(WorkoutSession.currentSet(of: run.workout) === current)
        #expect(current.reps == 7 && current.weightKg == 12.5)
        #expect(WorkoutSession.restRemaining(in: run.workout, at: now.addingTimeInterval(25)) == 35)
        run.demo.dismiss()
        #expect(run.demo.report == nil && run.player.commands.last == "stop")
    }

    @Test func aFailedVideoCanStillBeReportedAndRecoversWithRetry() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        #expect(run.demo.open(run.exercise))
        run.player.send(.failed, attempt: run.demo.attempt)
        #expect(run.demo.phase == .unavailable)
        run.demo.beginReport()
        #expect(run.demo.report?.demo.videoID == "TESTONLY001")
        run.demo.closeReport()
        #expect(run.demo.phase == .unavailable, "Failure is kept so Retry stays available")
        run.demo.retry()
        #expect(run.demo.phase == .loading)

        // An external link handoff stops the player; reporting then must not reload it either.
        let url = try #require(URL(string: "https://www.youtube.com/watch?v=TESTONLY001"))
        run.player.send(.mainFrameLink(url), attempt: run.demo.attempt)
        #expect(run.demo.phase == .stoppedForLink)
        run.demo.beginReport()
        run.demo.closeReport()
        #expect(run.demo.phase == .stoppedForLink)
        #expect(run.player.commands.filter { $0.hasPrefix("load") }.count == 2)
    }

    @Test func noReportWithoutAReviewedVideoOnView() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(
            in: container.mainContext, demos: [synthetic("goblet-squat", [.dumbbell], video: "TESTONLY001")])
        run.demo.beginReport()
        #expect(run.demo.report == nil, "Nothing presented yet")
        #expect(run.demo.open(run.exercise))
        run.demo.select([.kettlebell])
        run.demo.beginReport()
        #expect(run.demo.report == nil, "An equipment choice with no reviewed demo has nothing to report")
        run.demo.copyReport()
        run.demo.openReport()
        #expect(run.clipboard.copied.isEmpty && run.link.urls.isEmpty)
    }

    @Test func dismissingDiscardsTheReportAndLateHandoffResultsAreIgnored() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        #expect(run.demo.open(run.exercise))
        run.demo.beginReport()
        run.demo.openReport()
        run.demo.dismiss()
        run.link.complete(false)
        #expect(run.demo.report == nil && run.demo.reportOutcome == nil)
        #expect(run.demo.open(run.exercise))
        run.demo.beginReport()
        #expect(run.demo.report?.description == "" && run.demo.reportOutcome == nil)
        run.link.complete(true)
        #expect(run.demo.reportOutcome == nil, "A result from an earlier report is not this report's")
    }

    @Test func aWorkoutOwnedByAnotherDeviceCannotBeReportedFrom() throws {
        let container = try TransmuteStore.makeTestContainer()
        let run = try fixture(in: container.mainContext)
        run.workout.startedOn = .watch
        #expect(!run.demo.open(run.exercise))
        run.demo.beginReport()
        #expect(run.demo.report == nil)
    }
}
