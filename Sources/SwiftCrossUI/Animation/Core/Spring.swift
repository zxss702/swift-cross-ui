import Foundation

/// A spring model used by spring-based animations.
public struct Spring: Hashable, Sendable {
    public var mass: Double
    public var stiffness: Double
    public var damping: Double

    private var configuredDuration: TimeInterval?
    private var configuredBounce: Double?

    public init(duration: TimeInterval = 0.5, bounce: Double = 0.0) {
        let duration = max(duration, 0.0001)
        let bounce = min(max(bounce, -1), 1)
        let omega = 8 / duration
        let dampingRatio = if bounce >= 0 {
            max(0.05, 1 - bounce * 0.7)
        } else {
            1 - bounce
        }
        self.init(
            mass: 1,
            stiffness: omega * omega,
            damping: 2 * dampingRatio * omega,
            allowOverDamping: true
        )
        configuredDuration = duration
        configuredBounce = bounce
    }

    public init(response: Double, dampingRatio: Double) {
        let response = max(response, 0.0001)
        let stiffness = 1 / (response * response)
        self.init(
            mass: 1,
            stiffness: stiffness,
            damping: 2 * dampingRatio * stiffness.squareRoot()
        )
    }

    public init(
        mass: Double = 1.0,
        stiffness: Double,
        damping: Double,
        allowOverDamping: Bool = false
    ) {
        self.mass = max(mass, 0.0001)
        self.stiffness = max(stiffness, 0.0001)
        if allowOverDamping {
            self.damping = max(damping, 0)
        } else {
            self.damping = min(max(damping, 0), 2 * (self.mass * self.stiffness).squareRoot())
        }
        configuredDuration = nil
        configuredBounce = nil
    }

    public init(
        settlingDuration: TimeInterval,
        dampingRatio: Double,
        epsilon: Double = 0.001
    ) {
        let duration = max(settlingDuration, 0.0001)
        self.init(
            mass: 1,
            stiffness: 64 / (duration * duration),
            damping: 16 * max(dampingRatio, 0) / duration,
            allowOverDamping: true
        )
    }

    public var duration: TimeInterval {
        configuredDuration ?? settlingDuration
    }

    public var bounce: Double {
        configuredBounce ?? max(0, 1 - dampingRatio)
    }

    public var response: Double {
        1 / stiffness.squareRoot()
    }

    public var dampingRatio: Double {
        damping / (2 * (mass * stiffness).squareRoot())
    }

    public var settlingDuration: TimeInterval {
        configuredDuration ?? max(
            0.001,
            4 / max(dampingRatio * (stiffness / mass).squareRoot(), 0.0001)
        )
    }

    public static var smooth: Spring {
        smooth()
    }

    public static func smooth(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Spring {
        Spring(duration: duration, bounce: extraBounce)
    }

    public static var snappy: Spring {
        snappy()
    }

    public static func snappy(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Spring {
        Spring(duration: duration, bounce: 0.15 + extraBounce)
    }

    public static var bouncy: Spring {
        bouncy()
    }

    public static func bouncy(
        duration: TimeInterval = 0.5,
        extraBounce: Double = 0.0
    ) -> Spring {
        Spring(duration: duration, bounce: 0.3 + extraBounce)
    }

    public func value<V: VectorArithmetic>(
        target: V,
        initialVelocity: V = .zero,
        time: TimeInterval
    ) -> V {
        let progress = springProgress(at: time)
        return target.scaled(by: progress) + initialVelocity.scaled(by: time * (1 - progress))
    }

    public func velocity<V: VectorArithmetic>(
        target: V,
        initialVelocity: V = .zero,
        time: TimeInterval
    ) -> V {
        let delta = 0.0001
        let a = value(target: target, initialVelocity: initialVelocity, time: time)
        let b = value(target: target, initialVelocity: initialVelocity, time: time + delta)
        return (b - a).scaled(by: 1 / delta)
    }

    public func update<V: VectorArithmetic>(
        value: inout V,
        velocity: inout V,
        target: V,
        deltaTime: TimeInterval
    ) {
        let force = force(target: target, position: value, velocity: velocity)
        velocity += force.scaled(by: deltaTime / mass)
        value += velocity.scaled(by: deltaTime)
    }

    public func force<V: VectorArithmetic>(target: V, position: V, velocity: V) -> V {
        (target - position).scaled(by: stiffness) - velocity.scaled(by: damping)
    }

    public func settlingDuration<V: VectorArithmetic>(
        target: V,
        initialVelocity: V = .zero,
        epsilon: Double
    ) -> TimeInterval {
        settlingDuration
    }

    public func value<V: Animatable>(
        fromValue: V,
        toValue: V,
        initialVelocity: V,
        time: TimeInterval
    ) -> V {
        var value = fromValue
        let delta = toValue.animatableData - fromValue.animatableData
        value.animatableData = fromValue.animatableData + self.value(target: delta, time: time)
        return value
    }

    public func velocity<V: Animatable>(
        fromValue: V,
        toValue: V,
        initialVelocity: V,
        time: TimeInterval
    ) -> V {
        var value = fromValue
        value.animatableData = self.velocity(
            target: toValue.animatableData - fromValue.animatableData,
            time: time
        )
        return value
    }

    public func force<V: Animatable>(
        fromValue: V,
        toValue: V,
        position: V,
        velocity: V
    ) -> V {
        var value = fromValue
        value.animatableData = force(
            target: toValue.animatableData,
            position: position.animatableData,
            velocity: velocity.animatableData
        )
        return value
    }

    public func settlingDuration<V: Animatable>(
        fromValue: V,
        toValue: V,
        initialVelocity: V,
        epsilon: Double
    ) -> TimeInterval {
        settlingDuration
    }

    private func springProgress(at time: TimeInterval) -> Double {
        let omega = (stiffness / mass).squareRoot()
        let zeta = dampingRatio
        let time = max(time, 0)
        if zeta < 1 {
            let damped = omega * (1 - zeta * zeta).squareRoot()
            let envelope = exp(-zeta * omega * time)
            let correction = zeta / max((1 - zeta * zeta).squareRoot(), 0.0001)
            return 1 - envelope * (cos(damped * time) + correction * sin(damped * time))
        } else if zeta == 1 {
            return 1 - (1 + omega * time) * exp(-omega * time)
        } else {
            return 1 - exp(-(omega / zeta) * time)
        }
    }
}
