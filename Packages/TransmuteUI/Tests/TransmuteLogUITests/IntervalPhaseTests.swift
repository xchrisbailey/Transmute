import Testing

@testable import TransmuteLogUI

struct IntervalPhaseTests {
    @Test func walksThroughWorkAndRest() {
        let start = IntervalPhase.at(0, rounds: 3, work: 20, rest: 10)
        #expect(start == IntervalPhase(round: 1, isWork: true, remaining: 20, isFinished: false, index: 0))
        let firstRest = IntervalPhase.at(25, rounds: 3, work: 20, rest: 10)
        #expect(firstRest == IntervalPhase(round: 1, isWork: false, remaining: 5, isFinished: false, index: 1))
        let lastWork = IntervalPhase.at(70, rounds: 3, work: 20, rest: 10)
        #expect(lastWork == IntervalPhase(round: 3, isWork: true, remaining: 10, isFinished: false, index: 4))
        #expect(IntervalPhase.at(80, rounds: 3, work: 20, rest: 10).isFinished)
    }

    @Test func aTimedSetIsOneRoundWithNoRest() {
        #expect(IntervalPhase.at(29, rounds: 1, work: 30, rest: 0).remaining == 1)
        #expect(IntervalPhase.at(30, rounds: 1, work: 30, rest: 0).isFinished)
    }
}
