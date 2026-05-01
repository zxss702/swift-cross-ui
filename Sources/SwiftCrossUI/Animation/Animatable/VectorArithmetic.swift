import Foundation

/// A type that can be interpolated by SwiftCrossUI's animation engine.
public protocol VectorArithmetic: AdditiveArithmetic, Sendable {
    /// Scales this value in place.
    mutating func scale(by rhs: Double)

    /// The squared magnitude of this value.
    var magnitudeSquared: Double { get }
}

extension VectorArithmetic {
    /// Returns a scaled copy of this value.
    public func scaled(by rhs: Double) -> Self {
        var copy = self
        copy.scale(by: rhs)
        return copy
    }

    /// Moves this value toward another value by the given amount.
    public mutating func interpolate(towards other: Self, amount: Double) {
        self += (other - self).scaled(by: amount)
    }

    /// Returns a value interpolated toward another value by the given amount.
    public func interpolated(towards other: Self, amount: Double) -> Self {
        var copy = self
        copy.interpolate(towards: other, amount: amount)
        return copy
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

extension CGFloat: VectorArithmetic {
    public mutating func scale(by rhs: Double) {
        self *= CGFloat(rhs)
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

extension CGFloat: Animatable {
    public typealias AnimatableData = CGFloat

    public var animatableData: CGFloat {
        get { self }
        set { self = newValue }
    }
}

extension AffineTransform: VectorArithmetic {
    public static var zero: AffineTransform {
        AffineTransform(linearTransform: .zero, translation: .zero)
    }

    public static func + (
        lhs: AffineTransform,
        rhs: AffineTransform
    ) -> AffineTransform {
        AffineTransform(
            linearTransform: lhs.linearTransform + rhs.linearTransform,
            translation: lhs.translation + rhs.translation
        )
    }

    public static func - (
        lhs: AffineTransform,
        rhs: AffineTransform
    ) -> AffineTransform {
        AffineTransform(
            linearTransform: lhs.linearTransform - rhs.linearTransform,
            translation: lhs.translation - rhs.translation
        )
    }

    public mutating func scale(by rhs: Double) {
        linearTransform *= rhs
        translation *= rhs
    }

    public var magnitudeSquared: Double {
        let linearMagnitude =
            linearTransform.x * linearTransform.x
            + linearTransform.y * linearTransform.y
            + linearTransform.z * linearTransform.z
            + linearTransform.w * linearTransform.w
        let translationMagnitude =
            translation.x * translation.x + translation.y * translation.y
        return linearMagnitude + translationMagnitude
    }
}
