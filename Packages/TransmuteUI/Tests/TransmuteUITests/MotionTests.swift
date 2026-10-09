import SwiftUI
import Testing

@testable import TransmuteUI

struct MotionTests {
    @Test func theAnimationRunsWithReduceMotionOff() {
        #expect(Motion.animation(.default, reducedTo: nil, reduceMotion: false) == .default)
        #expect(Motion.animation(.default, reducedTo: Motion.fade, reduceMotion: false) == .default)
    }

    @Test func reduceMotionDropsTheAnimation() {
        #expect(Motion.animation(.default, reducedTo: nil, reduceMotion: true) == nil)
    }

    @Test func reduceMotionCanFallBackToAFade() {
        #expect(Motion.animation(.default, reducedTo: Motion.fade, reduceMotion: true) == Motion.fade)
    }
}
