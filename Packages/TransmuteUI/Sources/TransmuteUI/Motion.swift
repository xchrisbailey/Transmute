import SwiftUI

/// The one place Reduce Motion is decided (#62). Anything that slides, scales or counts goes
/// through here instead of straight to SwiftUI, so the rule reads the same on iPhone, Mac
/// and Apple Watch: with Reduce Motion on, movement is dropped, and a fade or nothing at all
/// takes its place.
///
/// Call `animate` where you would call `withAnimation`, and use the modifiers where you would
/// use `.transition`, `.animation(_:value:)` and `.contentTransition`:
///
///     private let motion = Motion()
///
///     motion.animate { toast = nil }
///     Toast().motionTransition(.move(edge: .top).combined(with: .opacity))
///     List(rows).motionAnimation(value: rows)
///     Text(clock).motionContentTransition(.numericText(countsDown: true))
public struct Motion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    /// A short cross-fade, for the things that should still appear and go with Reduce Motion on.
    public static let fade = Animation.easeInOut(duration: 0.2)

    /// The animation to run: `animation` normally, `reduced` with Reduce Motion on.
    public static func animation(
        _ animation: Animation?, reducedTo reduced: Animation?, reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? reduced : animation
    }

    /// `withAnimation`, except that with Reduce Motion on it runs `reduced` instead, which is
    /// no animation unless you pass one such as `Motion.fade`.
    @discardableResult
    public func animate<Result>(
        _ animation: Animation? = .default, reducedTo reduced: Animation? = nil, _ body: () throws -> Result
    ) rethrows -> Result {
        try withAnimation(Self.animation(animation, reducedTo: reduced, reduceMotion: reduceMotion), body)
    }
}

extension View {
    /// `.transition`, except that with Reduce Motion on it uses `reduced`, a plain fade unless
    /// you say otherwise.
    public func motionTransition(_ transition: AnyTransition, reduced: AnyTransition = .opacity) -> some View {
        modifier(MotionTransition(full: transition, reduced: reduced))
    }

    /// `.animation(_:value:)`, except that with Reduce Motion on it doesn't animate.
    public func motionAnimation<Value: Equatable>(_ animation: Animation? = .default, value: Value) -> some View {
        modifier(MotionAnimation(animation: animation, value: value))
    }

    /// `.contentTransition`, except that with Reduce Motion on the content swaps without a
    /// numeric roll or blur.
    public func motionContentTransition(_ transition: ContentTransition) -> some View {
        modifier(MotionContentTransition(transition: transition))
    }
}

private struct MotionTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let full: AnyTransition
    let reduced: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? reduced : full)
    }
}

private struct MotionAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: Value

    func body(content: Content) -> some View {
        content.animation(Motion.animation(animation, reducedTo: nil, reduceMotion: reduceMotion), value: value)
    }
}

private struct MotionContentTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: ContentTransition

    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : transition)
    }
}
