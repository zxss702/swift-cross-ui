/// A zero-sized value for types that do not expose animatable state.
@frozen
public struct EmptyAnimatableData: VectorArithmetic, Equatable {
    public init() {}

    public static var zero: Self {
        Self()
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self()
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self()
    }

    public static func += (lhs: inout Self, rhs: Self) {}

    public static func -= (lhs: inout Self, rhs: Self) {}

    public mutating func scale(by rhs: Double) {}

    public var magnitudeSquared: Double {
        0
    }
}
