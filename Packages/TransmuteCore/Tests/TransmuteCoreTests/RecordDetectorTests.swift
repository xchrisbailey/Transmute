import Testing

@testable import TransmuteCore

struct RecordDetectorTests {
    func lift(_ id: Int, _ kg: Double, _ reps: Int, warmUp: Bool = false) -> RecordSet {
        RecordSet(id: id, weightKg: kg, reps: reps, isWarmUp: warmUp)
    }

    func bests(_ marks: RecordMark...) -> RecordBests {
        RecordBests(marks)
    }

    @Test func weightRepsMarksEveryRepMaxAtOrBelowTheReps() {
        let marks = RecordDetector.marks(for: lift(0, 100, 6), tracking: .weightReps)
        let repMaxes = marks.filter { $0.kind == .repMax }.compactMap(\.slot.reps)
        #expect(repMaxes == [1, 3, 5])
        #expect(marks.contains(RecordMark(kind: .estimatedOneRepMax, value: 120)))
    }

    @Test func aHeavierSetOfSixIsA5RMAndLeadsWithIt() {
        let current = bests(
            RecordMark(kind: .repMax, value: 110, reps: 1), RecordMark(kind: .repMax, value: 105, reps: 3),
            RecordMark(kind: .repMax, value: 95, reps: 5), RecordMark(kind: .estimatedOneRepMax, value: 125))
        let detection = RecordDetector.detect(lift(0, 100, 6), tracking: .weightReps, bests: current)
        #expect(detection.records == [RecordMark(kind: .repMax, value: 100, reps: 5)])
    }

    @Test func aLighterTripleAfterAHeavierSixIsNotA3RM() {
        var current = RecordBests()
        for mark in RecordDetector.marks(for: lift(0, 100, 6), tracking: .weightReps) {
            current.absorb(mark)
        }
        let detection = RecordDetector.detect(lift(1, 98, 3), tracking: .weightReps, bests: current)
        #expect(detection.records.isEmpty)
    }

    @Test func highRepSetsCountForThe10RM() {
        let current = bests(RecordMark(kind: .repMax, value: 50, reps: 10))
        let detection = RecordDetector.detect(lift(0, 60, 15), tracking: .weightReps, bests: current)
        #expect(detection.records == [RecordMark(kind: .repMax, value: 60, reps: 10)])
    }

    @Test func tiesAreNotRecords() {
        let current = bests(RecordMark(kind: .repMax, value: 100, reps: 5))
        #expect(RecordDetector.detect(lift(0, 100, 5), tracking: .weightReps, bests: current).records.isEmpty)
    }

    @Test func warmUpsAndUnfinishedSetsAreIgnored() {
        let current = bests(RecordMark(kind: .repMax, value: 50, reps: 5))
        #expect(
            RecordDetector.detect(lift(0, 100, 5, warmUp: true), tracking: .weightReps, bests: current).records.isEmpty)
        var open = lift(0, 100, 5)
        open.isCompleted = false
        #expect(RecordDetector.detect(open, tracking: .weightReps, bests: current).records.isEmpty)
    }

    @Test func noLoadOnAWeightedExerciseIsMaxReps() {
        let current = bests(RecordMark(kind: .maxReps, value: 8))
        let set = RecordSet(id: 0, reps: 10)
        #expect(
            RecordDetector.detect(set, tracking: .weightReps, bests: current).records == [
                RecordMark(kind: .maxReps, value: 10)
            ])
    }

    @Test func repsTrackingIsMaxReps() {
        let current = bests(RecordMark(kind: .maxReps, value: 20))
        let detection = RecordDetector.detect(RecordSet(id: 0, reps: 25), tracking: .reps, bests: current)
        #expect(detection.records == [RecordMark(kind: .maxReps, value: 25)])
    }

    @Test func timeTrackingIsLongestTime() {
        let current = bests(RecordMark(kind: .longestTime, value: 60))
        let detection = RecordDetector.detect(RecordSet(id: 0, seconds: 75), tracking: .time, bests: current)
        #expect(detection.records == [RecordMark(kind: .longestTime, value: 75)])
    }

    @Test func distanceTimeIsFastestForTheDistanceAndLongestDistance() {
        let current = bests(
            RecordMark(kind: .bestTime, value: 2.1, meters: 20), RecordMark(kind: .longestDistance, value: 20))
        let faster = RecordDetector.detect(
            RecordSet(id: 0, seconds: 1.9, meters: 20), tracking: .distanceTime, bests: current)
        #expect(faster.records == [RecordMark(kind: .bestTime, value: 1.9, meters: 20)])

        let slower = RecordDetector.detect(
            RecordSet(id: 1, seconds: 2.3, meters: 20), tracking: .distanceTime, bests: current)
        #expect(slower.records.isEmpty)

        // A first 40 m has nothing to beat for its time, but it's the furthest yet.
        let further = RecordDetector.detect(
            RecordSet(id: 2, seconds: 5, meters: 40), tracking: .distanceTime, bests: current)
        #expect(further.records == [RecordMark(kind: .longestDistance, value: 40)])
    }

    @Test func distancesMatchToTheNearestTenCentimetres() {
        #expect(RecordSlot(kind: .bestTime, meters: 18.29) == RecordSlot(kind: .bestTime, meters: 18.3))
        #expect(RecordSlot(kind: .repMax, meters: 5).meters == nil)
    }

    @Test func intervalsDontSetRecords() {
        let set = RecordSet(id: 0, reps: 8, seconds: 20)
        #expect(RecordDetector.marks(for: set, tracking: .intervals).isEmpty)
    }

    @Test func aBigJumpNeedsConfirmation() {
        let current = bests(
            RecordMark(kind: .repMax, value: 100, reps: 5), RecordMark(kind: .repMax, value: 110, reps: 1))
        let typo = RecordDetector.detect(lift(0, 1_000, 5), tracking: .weightReps, bests: current)
        #expect(typo.records.isEmpty)
        #expect(typo.needsConfirmation.first == RecordMark(kind: .repMax, value: 1_000, reps: 5))

        var confirmed = lift(0, 1_000, 5)
        confirmed.isConfirmed = true
        let real = RecordDetector.detect(confirmed, tracking: .weightReps, bests: current)
        #expect(real.needsConfirmation.isEmpty)
        #expect(real.records.first == RecordMark(kind: .repMax, value: 1_000, reps: 5))
    }

    @Test func theThresholdIsFiveTimes() {
        let current = bests(RecordMark(kind: .maxReps, value: 4))
        let quadrupled = RecordDetector.detect(RecordSet(id: 0, reps: 20), tracking: .reps, bests: current)
        #expect(quadrupled.records.count == 1)
        let tooFar = RecordDetector.detect(RecordSet(id: 0, reps: 21), tracking: .reps, bests: current)
        #expect(tooFar.needsConfirmation.count == 1)

        let time = bests(RecordMark(kind: .bestTime, value: 10, meters: 60))
        let impossible = RecordDetector.detect(
            RecordSet(id: 0, seconds: 1.5, meters: 60), tracking: .distanceTime, bests: time)
        #expect(impossible.needsConfirmation.count == 1)
    }

    @Test func nothingTurnsGoldInTheFirstSession() {
        let current = bests(RecordMark(kind: .repMax, value: 60, reps: 5))
        let detection = RecordDetector.detect(
            lift(1, 80, 5), tracking: .weightReps, bests: current, isFirstSession: true)
        #expect(detection.records.isEmpty)
        #expect(RecordDetector.detect(lift(0, 80, 5), tracking: .weightReps, bests: RecordBests()).records.isEmpty)
    }

    @Test func sessionVolumeTurnsGoldOnTheSetThatCrossesTheBest() {
        let current = bests(
            RecordMark(kind: .sessionVolume, value: 1_000), RecordMark(kind: .repMax, value: 200, reps: 5))
        let session = [lift(0, 100, 5), lift(1, 100, 5)]
        let second = RecordDetector.detect(session[1], session: session, tracking: .weightReps, bests: current)
        #expect(second.records.isEmpty)

        let crossing = session + [lift(2, 100, 5)]
        let third = RecordDetector.detect(crossing[2], session: crossing, tracking: .weightReps, bests: current)
        #expect(third.records == [RecordMark(kind: .sessionVolume, value: 1_500)])

        let after = crossing + [lift(3, 100, 5)]
        let fourth = RecordDetector.detect(after[3], session: after, tracking: .weightReps, bests: current)
        #expect(fourth.records.isEmpty)
    }

    @Test func replaySetsBaselinesThenRecords() {
        let sessions = [
            RecordSession(sets: [lift(0, 60, 5, warmUp: true), lift(1, 90, 5), lift(2, 95, 5)]),
            RecordSession(sets: [lift(3, 95, 5), lift(4, 97.5, 5), lift(5, 97.5, 5)]),
        ]
        let replay = RecordDetector.replay(sessions, tracking: .weightReps)
        let first = replay.records.filter { $0.setID == 4 }.map(\.mark)
        #expect(first.first == RecordMark(kind: .repMax, value: 97.5, reps: 5))
        #expect(first.contains(RecordMark(kind: .sessionVolume, value: 95 * 5 + 97.5 * 10)))
        #expect(replay.records.allSatisfy { $0.setID >= 3 })
        #expect(replay.bests[RecordSlot(kind: .repMax, reps: 5)] == 97.5)
    }

    @Test func replaySkipsUnconfirmedJumps() {
        let sessions = [
            RecordSession(sets: [lift(0, 100, 5)]),
            RecordSession(sets: [lift(1, 1_000, 5), lift(2, 102.5, 5)]),
        ]
        let replay = RecordDetector.replay(sessions, tracking: .weightReps)
        #expect(replay.needsConfirmation.allSatisfy { $0.setID == 1 })
        #expect(!replay.needsConfirmation.isEmpty)
        #expect(replay.records.contains(RecordEvent(setID: 2, mark: RecordMark(kind: .repMax, value: 102.5, reps: 5))))
        // The typo doesn't add to the session's volume either: 102.5 × 5 beats 500 on its own.
        #expect(replay.records.contains(RecordEvent(setID: 2, mark: RecordMark(kind: .sessionVolume, value: 512.5))))
    }
}
