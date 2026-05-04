/// A SwiftUI-style transition.
public protocol Transition {
    associatedtype Body: View

    typealias Content = PlaceholderContentView<Self>

    @ViewBuilder @MainActor func body(content: Content, phase: TransitionPhase) -> Body

    static var properties: TransitionProperties { get }
}

extension Transition {
    public static var properties: TransitionProperties {
        TransitionProperties()
    }

    @ViewBuilder @MainActor
    public func apply<V: View>(content: V, phase: TransitionPhase) -> some View {
        body(content: PlaceholderContentView<Self>(content), phase: phase)
    }

    @MainActor
    public func animation(_ animation: Animation?) -> some Transition {
        AnimationScopedTransition(base: self, animation: animation)
    }

    @MainActor
    public func combined<T: Transition>(with other: T) -> some Transition {
        CombinedTransition(first: self, second: other)
    }
}

extension Transition where Self == IdentityTransition {
    public static var identity: IdentityTransition {
        IdentityTransition()
    }
}

extension Transition where Self == OpacityTransition {
    public static var opacity: OpacityTransition {
        OpacityTransition()
    }
}

extension Transition where Self == ScaleTransition {
    public static var scale: ScaleTransition {
        ScaleTransition()
    }

    public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> Self {
        ScaleTransition(scale: scale, anchor: anchor)
    }
}

extension Transition where Self == SlideTransition {
    public static var slide: SlideTransition {
        SlideTransition()
    }
}

extension Transition where Self == BlurReplaceTransition {
    public static var blurReplace: BlurReplaceTransition {
        BlurReplaceTransition()
    }

    public static func blurReplace(
        _ config: BlurReplaceTransition.Configuration = .downUp
    ) -> Self {
        BlurReplaceTransition(config)
    }
}

extension Transition {
    public static func move(edge: Edge) -> Self where Self == MoveTransition {
        MoveTransition(edge: edge)
    }

    public static func offset(_ offset: ViewSize) -> Self where Self == OffsetTransition {
        OffsetTransition(offset: offset)
    }

    public static func offset(
        x: Double = 0,
        y: Double = 0
    ) -> Self where Self == OffsetTransition {
        OffsetTransition(offset: ViewSize(x, y))
    }

    public static func push(from edge: Edge) -> Self where Self == PushTransition {
        PushTransition(edge: edge)
    }
}

struct CombinedTransition<First: Transition, Second: Transition>: Transition {
    var first: First
    var second: Second

    static var properties: TransitionProperties {
        TransitionProperties(
            hasMotion: First.properties.hasMotion || Second.properties.hasMotion
        )
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        second.apply(content: first.apply(content: content, phase: phase), phase: phase)
    }
}

struct AnimationScopedTransition<Base: Transition>: Transition {
    var base: Base
    var animation: Animation?

    static var properties: TransitionProperties {
        Base.properties
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        base.apply(content: content, phase: phase)
            .transaction { transaction in
                if !transaction.disablesAnimations {
                    transaction.animation = animation
                }
            }
    }
}
