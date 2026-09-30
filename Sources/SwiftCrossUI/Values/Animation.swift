/// An animation specification, as in SwiftUI.
///
/// SwiftCrossUI does not yet interpolate animations; the value exists so that
/// call sites match SwiftUI, and backends can honor it once animation support
/// lands. Until then, mutations apply immediately.
public struct Animation: Sendable, Equatable {
    /// Creates an animation.
    public init() {}

    /// A snappy spring animation.
    public static let snappy = Animation()
    /// A bouncy spring animation.
    public static let bouncy = Animation()
    /// The default animation.
    public static let `default` = Animation()
    /// An ease-in-out animation.
    public static let easeInOut = Animation()
    /// An ease-out animation.
    public static let easeOut = Animation()
    /// An ease-in animation.
    public static let easeIn = Animation()
    /// A linear animation.
    public static let linear = Animation()

    /// An ease-in-out animation with the specified duration.
    public static func easeInOut(duration: Double) -> Animation { Animation() }
    /// An ease-out animation with the specified duration.
    public static func easeOut(duration: Double) -> Animation { Animation() }
    /// An ease-in animation with the specified duration.
    public static func easeIn(duration: Double) -> Animation { Animation() }
    /// A linear animation with the specified duration.
    public static func linear(duration: Double) -> Animation { Animation() }
    /// A spring animation with the specified duration and bounce.
    public static func spring(duration: Double = 0.5, bounce: Double = 0) -> Animation {
        Animation()
    }
    /// A spring animation with the specified parameters.
    public static func spring(
        response: Double = 0.5,
        dampingFraction: Double = 0.825,
        blendDuration: Double = 0
    ) -> Animation { Animation() }
    /// An interpolating spring animation with the specified parameters.
    public static func interpolatingSpring(
        mass: Double = 1.0,
        stiffness: Double,
        damping: Double,
        initialVelocity: Double = 0.0
    ) -> Animation { Animation() }
    /// A smooth animation with the specified duration.
    public static func smooth(
        duration: Double = 0.5,
        extraBounce: Double = 0
    ) -> Animation { Animation() }
    /// A timing-curve animation.
    public static func timingCurve(
        _ c0x: Double,
        _ c0y: Double,
        _ c1x: Double,
        _ c1y: Double,
        duration: Double = 0.35
    ) -> Animation { Animation() }

    /// Returns a copy of the animation with its speed multiplied, as in SwiftUI.
    public func speed(_ speed: Double) -> Animation { self }
    /// Returns a copy of the animation with a delay, as in SwiftUI.
    public func delay(_ delay: Double) -> Animation { self }
    /// Returns a copy of the animation that repeats, as in SwiftUI.
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation { self }
    /// Returns a copy of the animation that repeats forever, as in SwiftUI.
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
}

/// Applies an animation to a state mutation, as in SwiftUI.
///
/// SwiftCrossUI does not yet interpolate animations; the action runs
/// immediately and the animation parameter is ignored.
@discardableResult
public func withAnimation<Result>(
    _ animation: Animation? = nil,
    action: () throws -> Result
) rethrows -> Result {
    try action()
}

/// Applies an animation to an async state mutation, as in SwiftUI.
@discardableResult
public func withAnimation<Result>(
    _ animation: Animation? = nil,
    action: () async throws -> Result
) async rethrows -> Result {
    try await action()
}

/// The transaction context passed to animations, as in SwiftUI.
public struct Transaction: Sendable {
    /// The animation applied to state changes in this transaction.
    public var animation: Animation?

    /// Creates a transaction.
    public init(animation: Animation? = nil) {
        self.animation = animation
    }
}

/// Runs a mutation inside a transaction, as in SwiftUI.
public func withTransaction<Result>(
    _ transaction: Transaction,
    _ action: () throws -> Result
) rethrows -> Result {
    try action()
}
