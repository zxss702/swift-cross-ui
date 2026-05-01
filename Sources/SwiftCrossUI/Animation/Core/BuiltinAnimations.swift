import Foundation

protocol EstimatedDurationAnimation {
    var estimatedDuration: TimeInterval { get }
}

struct CurveAnimation: CustomAnimation, EstimatedDurationAnimation {
    var curve: UnitCurve
    var duration: TimeInterval

    var estimatedDuration: TimeInterval {
        duration
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        guard duration > 0 else {
            context.isLogicallyComplete = true
            return value
        }
        let progress = min(max(time / duration, 0), 1)
        context.isLogicallyComplete = progress >= 1
        return value.scaled(by: curve.value(at: progress))
    }

    func velocity<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: AnimationContext<V>
    ) -> V? {
        guard duration > 0 else {
            return nil
        }
        let progress = min(max(time / duration, 0), 1)
        return value.scaled(by: curve.velocity(at: progress) / duration)
    }
}

struct SpringAnimation: CustomAnimation, EstimatedDurationAnimation {
    var spring: Spring
    var blendDuration: TimeInterval = 0
    var initialVelocity: Double = 0

    var estimatedDuration: TimeInterval {
        spring.settlingDuration + blendDuration
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        let velocity = value.scaled(by: initialVelocity)
        context.isLogicallyComplete = time >= spring.settlingDuration
        return spring.value(target: value, initialVelocity: velocity, time: time)
    }

    func velocity<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: AnimationContext<V>
    ) -> V? {
        spring.velocity(target: value, time: time)
    }
}

struct DelayedAnimation: CustomAnimation, EstimatedDurationAnimation {
    var base: Animation
    var delay: TimeInterval

    var estimatedDuration: TimeInterval {
        base.estimatedDuration + delay
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        guard time >= delay else {
            return .zero
        }
        return base.animate(value: value, time: time - delay, context: &context)
    }
}

struct SpeedAnimation: CustomAnimation, EstimatedDurationAnimation {
    var base: Animation
    var speed: Double

    var estimatedDuration: TimeInterval {
        guard speed != 0 else {
            return base.estimatedDuration
        }
        return base.estimatedDuration / abs(speed)
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        base.animate(value: value, time: time * speed, context: &context)
    }
}

struct RepeatedAnimation: CustomAnimation, EstimatedDurationAnimation {
    var base: Animation
    var repeatCount: Int?
    var autoreverses: Bool

    var estimatedDuration: TimeInterval {
        guard let repeatCount else {
            return .infinity
        }
        return base.estimatedDuration * Double(max(repeatCount, 1))
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        let cycleDuration = max(base.estimatedDuration, 0.0001)
        let cycle = Int(time / cycleDuration)
        if let repeatCount, cycle >= repeatCount {
            context.isLogicallyComplete = true
            return autoreverses && repeatCount.isMultiple(of: 2) ? .zero : value
        }

        var cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
        if autoreverses && !cycle.isMultiple(of: 2) {
            cycleTime = cycleDuration - cycleTime
        }

        var baseContext = context
        baseContext.isLogicallyComplete = false
        let result = base.animate(value: value, time: cycleTime, context: &baseContext)
        context = baseContext
        context.isLogicallyComplete = false
        return result
    }
}

struct LogicalCompletionAnimation: CustomAnimation, EstimatedDurationAnimation {
    var base: Animation
    var duration: TimeInterval

    var estimatedDuration: TimeInterval {
        max(base.estimatedDuration, duration)
    }

    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V? {
        let result = base.animate(value: value, time: time, context: &context)
        if time >= duration {
            context.isLogicallyComplete = true
        }
        return result
    }
}
