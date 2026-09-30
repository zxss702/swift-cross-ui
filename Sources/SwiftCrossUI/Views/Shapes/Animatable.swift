import Foundation

/// A type that can serve as the animated data of an ``Animatable`` value, as
/// in SwiftUI.
public protocol VectorArithmetic: AdditiveArithmetic, Sendable {
    /// Multiplies the value by a scalar.
    mutating func scale(by rhs: Double)
    /// The squared magnitude of the value.
    var magnitudeSquared: Double { get }
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

extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) {
        self *= CGFloat(rhs)
    }

    public var magnitudeSquared: Double {
        Double(self * self)
    }
}

/// A pair of animatable values, as in SwiftUI.
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
    /// The first value.
    public var first: First
    /// The second value.
    public var second: Second

    /// Creates an animatable pair from two values.
    public init(_ first: First, _ second: Second) {
        self.first = first
        self.second = second
    }

    public static var zero: AnimatablePair {
        AnimatablePair(.zero, .zero)
    }

    public static func + (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair {
        AnimatablePair(lhs.first + rhs.first, lhs.second + rhs.second)
    }

    public static func - (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair {
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

/// An empty animatable data type, as in SwiftUI.
public struct EmptyAnimatableData: VectorArithmetic {
    public init() {}

    public static var zero: EmptyAnimatableData {
        EmptyAnimatableData()
    }

    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData()
    }

    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData {
        EmptyAnimatableData()
    }

    public mutating func scale(by rhs: Double) {}

    public var magnitudeSquared: Double {
        0
    }
}

/// A type describing how a view animates, as in SwiftUI.
public protocol Animatable {
    /// The type containing the mutable data to animate.
    associatedtype AnimatableData: VectorArithmetic
    /// The data to animate.
    var animatableData: AnimatableData { get set }
}
