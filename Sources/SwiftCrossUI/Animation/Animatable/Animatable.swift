/// A type whose visual state can be animated.
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic

    /// The value SwiftCrossUI interpolates when animating this type.
    var animatableData: AnimatableData { get set }
}

extension Animatable where Self: VectorArithmetic, AnimatableData == Self {
    public var animatableData: Self {
        get { self }
        set { self = newValue }
    }
}

/// Marks a value as intentionally ignored by animation.
@propertyWrapper
public struct AnimatableIgnored<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}
