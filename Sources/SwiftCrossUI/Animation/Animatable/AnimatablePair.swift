/// A pair of animatable values.
@frozen
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>:
    VectorArithmetic, Equatable
where First: Equatable, Second: Equatable {
    public var first: First
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public static var zero: Self {
        Self(.zero, .zero)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs.first + rhs.first, lhs.second + rhs.second)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(lhs.first - rhs.first, lhs.second - rhs.second)
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.first += rhs.first
        lhs.second += rhs.second
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs.first -= rhs.first
        lhs.second -= rhs.second
    }

    public mutating func scale(by rhs: Double) {
        first.scale(by: rhs)
        second.scale(by: rhs)
    }

    public var magnitudeSquared: Double {
        first.magnitudeSquared + second.magnitudeSquared
    }
}

