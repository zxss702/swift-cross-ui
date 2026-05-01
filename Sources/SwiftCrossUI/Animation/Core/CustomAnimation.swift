import Foundation

/// A custom animation implementation.
public protocol CustomAnimation: Hashable, Sendable {
    func animate<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> V?

    func velocity<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: AnimationContext<V>
    ) -> V?

    func shouldMerge<V: VectorArithmetic>(
        previous: Animation,
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> Bool
}

extension CustomAnimation {
    public func velocity<V: VectorArithmetic>(
        value: V,
        time: TimeInterval,
        context: AnimationContext<V>
    ) -> V? {
        nil
    }

    public func shouldMerge<V: VectorArithmetic>(
        previous: Animation,
        value: V,
        time: TimeInterval,
        context: inout AnimationContext<V>
    ) -> Bool {
        false
    }
}

