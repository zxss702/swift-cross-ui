import Foundation

/// A SwiftUI-compatible value describing how animatable data changes over time.
@frozen
public struct Animation: Hashable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let base: any CustomAnimation

    public static let `default` = Animation.timingCurve(.easeInOut, duration: 0.35)
    public static let linear = Animation.linear(duration: 0.35)
    public static let easeIn = Animation.easeIn(duration: 0.35)
    public static let easeOut = Animation.easeOut(duration: 0.35)
    public static let easeInOut = Animation.easeInOut(duration: 0.35)
    public static let spring = Animation.spring(
        duration: 0.5,
        bounce: 0,
        blendDuration: 0
    )
    public static let interactiveSpring = Animation.interactiveSpring(
        response: 0.15,
        dampingFraction: 0.86,
        blendDuration: 0.25
    )
    public static let interpolatingSpring = Animation.interpolatingSpring(
        duration: 0.5,
        bounce: 0,
        initialVelocity: 0
    )
    public static let smooth = Animation.smooth()
    public static let snappy = Animation.snappy()
    public static let bouncy = Animation.bouncy()

    public init<A: CustomAnimation>(_ base: A) {
        self.base = base
    }

    public static func timingCurve(_ curve: UnitCurve, duration: TimeInterval) -> Animation {
        Animation(CurveAnimation(curve: curve, duration: duration))
    }

    public static func timingCurve(
        _ p1x: Double,
        _ p1y: Double,
        _ p2x: Double,
        _ p2y: Double,
        duration: TimeInterval = 0.35
    ) -> Animation {
        timingCurve(
            .bezier(
                startControlPoint: UnitPoint(x: p1x, y: p1y),
                endControlPoint: UnitPoint(x: p2x, y: p2y)
            ),
            duration: duration
        )
    }

    public static func linear(duration: TimeInterval) -> Animation {
        timingCurve(.linear, duration: duration)
    }

    public static func easeIn(duration: TimeInterval) -> Animation {
        timingCurve(.easeIn, duration: duration)
    }

    public static func easeOut(duration: TimeInterval) -> Animation {
        timingCurve(.easeOut, duration: duration)
    }

    public static func easeInOut(duration: TimeInterval) -> Animation {
        timingCurve(.easeInOut, duration: duration)
    }

    public static func spring(
        _ spring: Spring,
        blendDuration: TimeInterval = 0.0
    ) -> Animation {
        Animation(SpringAnimation(spring: spring, blendDuration: blendDuration))
    }

    public static func spring(
        duration: TimeInterval = 0.5,
        bounce: Double = 0.0,
        blendDuration: Double = 0
    ) -> Animation {
        spring(Spring(duration: duration, bounce: bounce), blendDuration: blendDuration)
    }

    public static func spring(
        response: Double = 0.5,
        dampingFraction: Double = 0.825,
        blendDuration: TimeInterval = 0
    ) -> Animation {
        spring(
            Spring(response: response, dampingRatio: dampingFraction),
            blendDuration: blendDuration
        )
    }

    public static func interpolatingSpring(
        _ spring: Spring,
        initialVelocity: Double = 0.0
    ) -> Animation {
        Animation(SpringAnimation(spring: spring, initialVelocity: initialVelocity))
    }

    public static func interpolatingSpring(
        mass: Double = 1.0,
        stiffness: Double,
        damping: Double,
        initialVelocity: Double = 0.0
    ) -> Animation {
        interpolatingSpring(
            Spring(mass: mass, stiffness: stiffness, damping: damping),
            initialVelocity: initialVelocity
        )
    }

    public static func interpolatingSpring(
        duration: TimeInterval = 0.5,
        bounce: Double = 0.0,
        initialVelocity: Double = 0.0
    ) -> Animation {
        interpolatingSpring(
            Spring(duration: duration, bounce: bounce),
            initialVelocity: initialVelocity
        )
    }

    public static func interactiveSpring(
        response: Double = 0.15,
        dampingFraction: Double = 0.86,
        blendDuration: TimeInterval = 0.25
    ) -> Animation {
        spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }

    public static func interactiveSpring(
        duration: TimeInterval = 0.15,
        extraBounce: Double = 0.0,
        blendDuration: TimeInterval = 0.25
    ) -> Animation {
        spring(
            duration: duration,
            bounce: extraBounce,
            blendDuration: blendDuration
        )
    }

    public static func smooth(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Animation {
        spring(.smooth(duration: duration, extraBounce: extraBounce))
    }

    public static func snappy(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Animation {
        spring(.snappy(duration: duration, extraBounce: extraBounce))
    }

    public static func bouncy(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Animation {
        spring(.bouncy(duration: duration, extraBounce: extraBounce))
    }

    public func delay(_ delay: TimeInterval) -> Animation {
        Animation(DelayedAnimation(base: self, delay: delay))
    }

    public func speed(_ speed: Double) -> Animation {
        Animation(SpeedAnimation(base: self, speed: speed))
    }

    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation {
        Animation(
            RepeatedAnimation(
                base: self,
                repeatCount: repeatCount,
                autoreverses: autoreverses
            )
        )
    }

    public func repeatForever(autoreverses: Bool = true) -> Animation {
        Animation(
            RepeatedAnimation(
                base: self,
                repeatCount: nil,
                autoreverses: autoreverses
            )
        )
    }

    public func logicallyComplete(after duration: TimeInterval) -> Animation {
        Animation(LogicalCompletionAnimation(base: self, duration: duration))
    }

    public func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        base.animate(value: value, time: time, context: &context)
    }

    public func velocity<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: AnimationContext<V>
    ) -> V? {
        base.velocity(value: value, time: time, context: context)
    }

    public func shouldMerge<V: VectorArithmetic>(
        previous: Animation,
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> Bool {
        base.shouldMerge(previous: previous, value: value, time: time, context: &context)
    }

    public static func == (lhs: Animation, rhs: Animation) -> Bool {
        AnyHashable(lhs.base) == AnyHashable(rhs.base)
    }

    public func hash(into hasher: inout Hasher) {
        AnyHashable(base).hash(into: &hasher)
    }

    public var description: String {
        String(describing: base)
    }

    public var debugDescription: String {
        description
    }

    var estimatedDuration: TimeInterval {
        (base as? EstimatedDurationAnimation)?.estimatedDuration ?? 0.35
    }
}
