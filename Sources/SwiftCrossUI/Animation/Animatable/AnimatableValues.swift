/// A lightweight container for one animatable value.
///
/// SwiftUI exposes a variadic `AnimatableValues` type. SwiftCrossUI keeps this
/// source-compatible single-value form until the package can require a compiler
/// mode where public parameter packs are practical across all supported targets.
@frozen
public struct AnimatableValues<Value: VectorArithmetic>: VectorArithmetic, Equatable
where Value: Equatable {
    public var value: Value

    public init(_ value: Value) {
        self.value = value
    }

    public static var zero: Self {
        Self(.zero)
    }

    public static func + (lhs: Self, rhs: Self) -> Self {
        Self(lhs.value + rhs.value)
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        Self(lhs.value - rhs.value)
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.value += rhs.value
    }

    public static func -= (lhs: inout Self, rhs: Self) {
        lhs.value -= rhs.value
    }

    public mutating func scale(by rhs: Double) {
        value.scale(by: rhs)
    }

    public var magnitudeSquared: Double {
        value.magnitudeSquared
    }
}
