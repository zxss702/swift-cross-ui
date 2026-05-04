import Dispatch
import Foundation

@MainActor
final class PresentationAnimation<Value: VectorArithmetic>: @unchecked Sendable {
    private var target: Value?
    private var presentation: Value?
    private var startValue: Value = .zero
    private var delta: Value = .zero
    private var animation: Animation?
    private var transaction: Transaction?
    private var context = AnimationContext<Value>()
    private var startTime: DispatchTime?
    private var hasScheduledFrame = false

    var hasValue: Bool {
        target != nil
    }

    func value(
        for target: Value,
        transaction: Transaction,
        environment: EnvironmentValues,
        requestFrame: @escaping @MainActor (Transaction) -> Void
    ) -> Value {
        if environment.allowLayoutCaching {
            return target
        }

        if RenderFrameContext.isRendering {
            hasScheduledFrame = false
        }

        let now = RenderFrameContext.currentTime
        updatePresentation(at: now)

        guard let previousTarget = self.target else {
            setImmediately(to: target)
            return target
        }

        let targetDelta = target - previousTarget
        if targetDelta.magnitudeSquared > 0.000_000_001 {
            retarget(
                to: target,
                transaction: transaction,
                environment: environment,
                requestFrame: requestFrame
            )
        } else if animation != nil {
            scheduleFrame(requestFrame)
        }

        return presentation ?? target
    }

    private func retarget(
        to target: Value,
        transaction: Transaction,
        environment: EnvironmentValues,
        requestFrame: @escaping @MainActor (Transaction) -> Void
    ) {
        let currentPresentation = presentation ?? self.target ?? target
        self.target = target

        guard let animation = transaction.animation, !transaction.disablesAnimations else {
            setImmediately(to: target)
            return
        }

        startValue = currentPresentation
        delta = target - currentPresentation
        self.animation = animation
        self.transaction = transaction
        context = AnimationContext(environment: environment)
        startTime = nil
        presentation = currentPresentation
        scheduleFrame(requestFrame)
    }

    private func updatePresentation(at now: DispatchTime) {
        guard let animation, let target else {
            return
        }

        guard let startTime else {
            self.startTime = now
            presentation = startValue
            return
        }

        var animationContext = context
        let elapsed = now.secondsSince(startTime)
        if let animatedDelta = animation.animate(
            value: delta,
            time: elapsed,
            context: &animationContext
        ) {
            presentation = startValue + animatedDelta
        }
        context = animationContext

        if animationContext.isLogicallyComplete || elapsed >= animation.estimatedDuration {
            presentation = target
            self.animation = nil
            self.startTime = nil
            transaction?.runCompletions(matching: .logicallyComplete)
            transaction = nil
        }
    }

    private func setImmediately(to target: Value) {
        self.target = target
        presentation = target
        animation = nil
        startTime = nil
        transaction = nil
        hasScheduledFrame = false
    }

    func reset(to target: Value) {
        setImmediately(to: target)
    }

    private func scheduleFrame(
        _ requestFrame: @escaping @MainActor (Transaction) -> Void
    ) {
        guard animation != nil, !hasScheduledFrame else {
            return
        }
        hasScheduledFrame = true
        requestFrame(transaction ?? Transaction())
    }
}
