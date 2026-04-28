/// A vector space that can be interpolated by the animation runtime.
public protocol VectorArithmetic: AdditiveArithmetic, Sendable {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}

extension VectorArithmetic {
    public func scaled(by rhs: Double) -> Self {
        var value = self
        value.scale(by: rhs)
        return value
    }

    public mutating func interpolate(towards other: Self, amount: Double) {
        var delta = other - self
        delta.scale(by: amount)
        self += delta
    }

    public func interpolated(towards other: Self, amount: Double) -> Self {
        var value = self
        value.interpolate(towards: other, amount: amount)
        return value
    }
}

/// A type with data that can be interpolated by animations.
@MainActor
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic = EmptyAnimatableData

    var animatableData: AnimatableData { get set }
}

/// A zero-sized animatable value.
public struct EmptyAnimatableData: VectorArithmetic, Equatable {
    public init() {}

    public static let zero = EmptyAnimatableData()

    public static func + (
        lhs: EmptyAnimatableData,
        rhs: EmptyAnimatableData
    ) -> EmptyAnimatableData {
        EmptyAnimatableData()
    }

    public static func - (
        lhs: EmptyAnimatableData,
        rhs: EmptyAnimatableData
    ) -> EmptyAnimatableData {
        EmptyAnimatableData()
    }

    public mutating func scale(by rhs: Double) {}

    public var magnitudeSquared: Double {
        0
    }
}

/// A pair of animatable values.
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>:
    VectorArithmetic, Equatable
{
    public var first: First
    public var second: Second

    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public static var zero: AnimatablePair<First, Second> {
        AnimatablePair(.zero, .zero)
    }

    public static func + (
        lhs: AnimatablePair<First, Second>,
        rhs: AnimatablePair<First, Second>
    ) -> AnimatablePair<First, Second> {
        AnimatablePair(lhs.first + rhs.first, lhs.second + rhs.second)
    }

    public static func - (
        lhs: AnimatablePair<First, Second>,
        rhs: AnimatablePair<First, Second>
    ) -> AnimatablePair<First, Second> {
        AnimatablePair(lhs.first - rhs.first, lhs.second - rhs.second)
    }

    public mutating func scale(by rhs: Double) {
        first.scale(by: rhs)
        second.scale(by: rhs)
    }

    public var magnitudeSquared: Double {
        first.magnitudeSquared + second.magnitudeSquared
    }
}

extension Double: VectorArithmetic {
    public mutating func scale(by rhs: Double) {
        self *= rhs
    }

    public var magnitudeSquared: Double {
        self * self
    }
}

extension Float: VectorArithmetic {
    public mutating func scale(by rhs: Double) {
        self *= Float(rhs)
    }

    public var magnitudeSquared: Double {
        Double(self * self)
    }
}

extension Double: Animatable {
    public typealias AnimatableData = Double

    public var animatableData: Double {
        get { self }
        set { self = newValue }
    }
}

extension Float: Animatable {
    public typealias AnimatableData = Float

    public var animatableData: Float {
        get { self }
        set { self = newValue }
    }
}

/// A two-dimensional animatable vector.
public struct AnimatableVector2: VectorArithmetic, Equatable {
    public var x: Double
    public var y: Double

    public init(_ x: Double = 0, _ y: Double = 0) {
        self.x = x
        self.y = y
    }

    init(_ vector: SIMD2<Double>) {
        self.init(vector.x, vector.y)
    }

    var simd: SIMD2<Double> {
        SIMD2(x, y)
    }

    public static var zero: AnimatableVector2 {
        AnimatableVector2()
    }

    public static func + (
        lhs: AnimatableVector2,
        rhs: AnimatableVector2
    ) -> AnimatableVector2 {
        AnimatableVector2(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (
        lhs: AnimatableVector2,
        rhs: AnimatableVector2
    ) -> AnimatableVector2 {
        AnimatableVector2(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    public mutating func scale(by rhs: Double) {
        x *= rhs
        y *= rhs
    }

    public var magnitudeSquared: Double {
        x * x + y * y
    }
}

extension ViewModifier where Self: Animatable, AnimatableData == EmptyAnimatableData {
    public var animatableData: EmptyAnimatableData {
        get {
            EmptyAnimatableData()
        }
        set {}
    }
}

extension VectorArithmetic {
    static func interpolate(from: Self, to: Self, progress: Double) -> Self {
        var delta = to - from
        delta.scale(by: progress)
        return from + delta
    }
}
