import Foundation
import Testing

@testable import TransmuteCore

struct RestAnnouncementsTests {
    @Test func aThreeMinuteRestSpeaksAtEveryMinuteThenThirtyAndTen() {
        #expect(RestAnnouncements.marks(remaining: 180) == [180, 120, 60, 30, 10, 0])
    }

    @Test func aNinetySecondRestStartsAtNinety() {
        #expect(RestAnnouncements.marks(remaining: 90) == [90, 60, 30, 10, 0])
    }

    @Test func aThirtyFiveSecondRestDoesNotSpeakTwiceInARow() {
        // 35 and 30 are five seconds apart, so the start stands for both.
        #expect(RestAnnouncements.marks(remaining: 35) == [35, 10, 0])
    }

    @Test func aTenSecondRestSpeaksAtTheStartAndTheEnd() {
        #expect(RestAnnouncements.marks(remaining: 10) == [10, 0])
    }

    @Test func aRestWithNothingLeftOnlyEnds() {
        #expect(RestAnnouncements.marks(remaining: 0) == [0])
        #expect(RestAnnouncements.marks(remaining: -3) == [0])
    }

    @Test func theEndSurvivesAStartRightBesideIt() {
        #expect(RestAnnouncements.marks(remaining: 4) == [0])
    }

    @Test func marksWithinFiveSecondsCollapseOntoTheEarlierOne() {
        #expect(RestAnnouncements.marks(remaining: 65) == [65, 30, 10, 0])
        #expect(RestAnnouncements.marks(remaining: 66) == [66, 60, 30, 10, 0])
        #expect(RestAnnouncements.marks(remaining: 16) == [16, 10, 0])
        #expect(RestAnnouncements.marks(remaining: 15) == [15, 0])
        #expect(RestAnnouncements.marks(remaining: 14) == [14, 0])
    }

    @Test func aPartSecondRoundsUpToTheNextWholeSecond() {
        #expect(RestAnnouncements.marks(remaining: 89.2) == [90, 60, 30, 10, 0])
    }

    @Test func aRestExtendedMidWayIsPlannedAgainFromWhatIsLeft() {
        // 45 seconds into a 90 second rest, 15 more seconds make it 60 left.
        #expect(RestAnnouncements.marks(remaining: 60) == [60, 30, 10, 0])
        // Taking 15 off 40 left leaves 25, already past the 30 mark.
        #expect(RestAnnouncements.marks(remaining: 25) == [25, 10, 0])
    }
}
