import Foundation
import SwiftData
import Testing

@testable import TransmuteCore

@MainActor
struct SessionMessageTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    /// Not a whole second, so a lossy date encoding would show.
    let now = Date(timeIntervalSinceReferenceDate: 812_345_678.123_456_7)
    let first = SetRef(exerciseOrder: 0, setOrder: 0)

    init() throws {
        container = try TransmuteStore.makeContainer(.inMemory)
    }

    func session() throws -> Workout {
        let (_, plan) = SampleData.insert(into: context, now: now)
        try context.save()
        let day = try #require(plan.orderedDays.first { $0.week == 4 && $0.weekday == 1 })
        return WorkoutSession.start(day, at: now, in: context)
    }

    // MARK: Ending

    @Test func finishingKeepsOnlyWhatWasLogged() throws {
        let workout = try session()
        let values = SetValues(weightKg: 60, reps: 5)
        SessionMirror.apply(.logSet(first, values, at: now.addingTimeInterval(60)), to: workout, in: context)
        let end = now.addingTimeInterval(1800)
        let guess = SessionSnapshot(workout).applying(.finish(at: end))

        let outcome = SessionMirror.apply(.finish(at: end), to: workout, in: context)
        #expect(outcome == .finished(WorkoutSummary(sets: 1, exercises: 1, volumeKg: 300, duration: 1800)))
        let truth = SessionSnapshot(workout)
        #expect(guess == truth)
        #expect(truth.isFinished)
        #expect(truth.endedAt == end)
        #expect(truth.restEndsAt == nil)
        #expect(truth.exercises.count == 1)
        #expect(truth.exercises[0].sets.map(\.order) == [0])
        #expect(truth.current == nil)
        #expect(try WorkoutSession.current(in: context) == nil)
    }

    @Test func nothingChangesOnceTheSessionHasEnded() throws {
        let workout = try session()
        SessionMirror.apply(.logSet(first, SetValues(reps: 5), at: now), to: workout, in: context)
        SessionMirror.apply(.finish(at: now.addingTimeInterval(600)), to: workout, in: context)
        let ended = SessionSnapshot(workout)
        let commands: [SessionCommand] = [
            .logSet(first, SetValues(reps: 9), at: now), .reopenSet(first), .updateSet(first, SetValues(reps: 9)),
            .startRest(seconds: 60, at: now), .adjustRest(by: 15, at: now), .setSkipped(exerciseOrder: 0, true),
            .finish(at: now.addingTimeInterval(900)), .discard,
        ]
        for command in commands {
            #expect(ended.applying(command) == ended)
            #expect(SessionMirror.apply(command, to: workout, in: context) == .ignored)
            #expect(SessionSnapshot(workout) == ended)
        }
        #expect(try context.fetchCount(FetchDescriptor<Workout>(predicate: #Predicate { $0.endedAt != nil })) > 0)
    }

    @Test func discardingDeletesTheWorkout() throws {
        let workout = try session()
        let id = workout.id
        let before = SessionSnapshot(workout)
        // The mirror keeps what it has until the owner says the session ended.
        #expect(before.applying(.discard) == before)

        #expect(SessionMirror.apply(.discard, to: workout, in: context) == .discarded)
        #expect(try WorkoutSession.current(in: context) == nil)
        #expect(try context.fetchCount(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == id })) == 0)
    }

    // MARK: Messages

    @Test func everyMessageRoundTrips() throws {
        let workout = try session()
        let logged = SetValues(weightKg: 42.5, reps: 5, rpe: 7.5)
        SessionMirror.apply(.logSet(first, logged, at: now), to: workout, in: context)
        let id = workout.id
        let commands: [SessionCommand] = [
            .logSet(first, SetValues(weightKg: 0.1 + 0.2, reps: 5, seconds: 1.0 / 3, meters: 20, rpe: 8.5), at: now),
            .reopenSet(first), .updateSet(first, SetValues()), .startRest(seconds: 90, at: now),
            .startRest(seconds: nil, at: now), .adjustRest(by: -15, at: now), .setSkipped(exerciseOrder: 2, true),
            .finish(at: now), .discard,
        ]
        let messages: [SessionMessage] =
            commands.map { .command($0, workoutID: id) } + [
                .snapshot(SessionSnapshot(workout)), .heartRate(bpm: 142.5, at: now),
                .ended(workoutID: id, healthWorkoutID: UUID()), .ended(workoutID: id, healthWorkoutID: nil),
                .requestSnapshot,
            ]
        for message in messages {
            #expect(try SessionMessage(data: message.encoded()) == message)
        }
    }

    @Test func datesSurviveTheTripExactly() throws {
        let dates = [now, .distantPast, Date(timeIntervalSince1970: 0.000_001), now.addingTimeInterval(1.0 / 3)]
        for date in dates {
            let decoded = try SessionMessage(data: SessionMessage.heartRate(bpm: 60, at: date).encoded())
            guard case .heartRate(_, let back) = decoded else {
                Issue.record("Decoded as \(decoded)")
                continue
            }
            #expect(back.timeIntervalSinceReferenceDate == date.timeIntervalSinceReferenceDate)
        }
    }

    @Test func aNewerFormatIsRejectedNotCrashedOn() throws {
        let data = try SessionMessage.requestSnapshot.encoded()
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["version"] as? Int == SessionMessage.formatVersion)

        object["version"] = SessionMessage.formatVersion + 1
        let newer = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: SessionMessage.Failure.unsupportedVersion(SessionMessage.formatVersion + 1)) {
            try SessionMessage(data: newer)
        }
        object["version"] = 0
        let zero = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: SessionMessage.Failure.unsupportedVersion(0)) { try SessionMessage(data: zero) }
    }

    @Test func messagesThisBuildDoesNotKnowThrow() throws {
        let unknown = Data(#"{"version":1,"message":{"telepathy":{}}}"#.utf8)
        #expect(throws: DecodingError.self) { try SessionMessage(data: unknown) }
        #expect(throws: DecodingError.self) { try SessionMessage(data: Data(#"{"message":{}}"#.utf8)) }
        #expect(throws: (any Error).self) { try SessionMessage(data: Data("not json".utf8)) }
        #expect(throws: (any Error).self) { try SessionMessage(data: Data()) }
    }
}
