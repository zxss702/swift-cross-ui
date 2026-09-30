import Foundation

/// A transition describing how a view is inserted or removed, as in SwiftUI.
///
/// SwiftCrossUI does not yet animate transitions; the value exists so that
/// call sites match SwiftUI, and backends can honor it once transition
/// support lands.
public struct AnyTransition: Sendable {
    /// Creates a transition.
    public init() {}

    /// A transition that fades the view in or out.
    public static let opacity = AnyTransition()
    /// A transition that leaves the view unchanged.
    public static let identity = AnyTransition()
    /// A transition that scales the view in or out.
    public static let scale = AnyTransition()
    /// A transition that slides the view in or out.
    public static let slide = AnyTransition()
    /// A transition that blurs the view in or out.
    public static let blur = AnyTransition()
    /// A transition that moves the view to or from the leading edge.
    public static let moveLeading = AnyTransition()

    /// A transition that offsets the view by the given amount.
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition {
        AnyTransition()
    }

    /// A transition that offsets the view by the given amount.
    public static func offset(_ offset: CGSize) -> AnyTransition {
        AnyTransition()
    }

    /// A transition that moves the view to or from the given edge.
    public static func move(edge: Edge) -> AnyTransition {
        AnyTransition()
    }

    /// A transition that slides the view in or out along the given edge,
    /// respecting the layout direction.
    public static func push(from edge: Edge) -> AnyTransition {
        AnyTransition()
    }

    /// A transition that scales the view by the given factor.
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        AnyTransition()
    }

    /// A transition that scales the view by the given factors.
    public static func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center)
        -> AnyTransition
    {
        AnyTransition()
    }

    /// A transition built from separate insertion and removal transitions.
    public static func asymmetric(
        insertion: AnyTransition,
        removal: AnyTransition
    ) -> AnyTransition {
        AnyTransition()
    }

    /// Combines this transition with another, as in SwiftUI.
    public func combined(with other: AnyTransition) -> AnyTransition {
        self
    }

    /// Associates an animation with this transition, as in SwiftUI.
    public func animation(_ animation: Animation) -> AnyTransition {
        self
    }
}

extension View {
    /// Associates a transition with the view, as in SwiftUI.
    ///
    /// Currently a no-op; transitions are not yet animated.
    public func transition(_ transition: AnyTransition) -> some View {
        self
    }

    /// Binds animations for changes to the given value, as in SwiftUI.
    ///
    /// Currently a no-op; animations are not yet interpolated.
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        self
    }

    /// Binds the given animation to the view's state changes, as in SwiftUI.
    ///
    /// Currently a no-op; animations are not yet interpolated.
    public func animation(_ animation: Animation?) -> some View {
        self
    }
}

extension Binding {
    /// Returns a binding whose mutations run under the given animation, as in
    /// SwiftUI.
    ///
    /// Currently a no-op; animations are not yet interpolated.
    public func animation(_ animation: Animation = .default) -> Binding<Value> {
        self
    }

    /// Returns a binding whose mutations run inside the given transaction, as
    /// in SwiftUI.
    public func transaction(_ transaction: Transaction) -> Binding<Value> {
        self
    }
}
