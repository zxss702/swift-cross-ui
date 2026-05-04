import Foundation

/// A type-erased transition.
public struct AnyTransition: @unchecked Sendable {
    public static let identity = AnyTransition(IdentityTransition())
    public static let opacity = AnyTransition(OpacityTransition())
    public static let scale = AnyTransition(ScaleTransition())
    public static let slide = AnyTransition(SlideTransition())
    public static let blurReplace = AnyTransition(BlurReplaceTransition())

    let applyTransition: @MainActor (AnyView, TransitionPhase) -> AnyView
    let properties: TransitionProperties
    let animationOverride: Animation?
    let hasAnimationOverride: Bool

    public init<T: Transition>(_ transition: T) {
        self.properties = T.properties
        self.animationOverride = nil
        self.hasAnimationOverride = false
        let box: AnyTransitionApplier
        if T.self == IdentityTransition.self {
            box = AnyTransitionApplier { content, _ in
                content
            }
        } else {
            let unsafeTransition = UnsafeTransition(value: transition)
            box = AnyTransitionApplier { content, phase in
                AnyView(unsafeTransition.value.apply(content: content, phase: phase))
            }
        }
        self.applyTransition = { content, phase in
            box.apply(content, phase)
        }
    }

    private init(
        properties: TransitionProperties,
        animationOverride: Animation?,
        hasAnimationOverride: Bool,
        applyTransition: @escaping @MainActor (AnyView, TransitionPhase) -> AnyView
    ) {
        self.properties = properties
        self.animationOverride = animationOverride
        self.hasAnimationOverride = hasAnimationOverride
        self.applyTransition = applyTransition
    }

    public static func move(edge: Edge) -> AnyTransition {
        AnyTransition(MoveTransition(edge: edge))
    }

    public static func offset(_ offset: ViewSize) -> AnyTransition {
        AnyTransition(OffsetTransition(offset: offset))
    }

    public static func offset(x: Double = 0, y: Double = 0) -> AnyTransition {
        AnyTransition(OffsetTransition(offset: ViewSize(x, y)))
    }

    public static func push(from edge: Edge) -> AnyTransition {
        AnyTransition(PushTransition(edge: edge))
    }

    public static func blurReplace(
        _ config: BlurReplaceTransition.Configuration = .downUp
    ) -> AnyTransition {
        AnyTransition(BlurReplaceTransition(config))
    }

    public static func scale(
        scale: Double,
        anchor: UnitPoint = .center
    ) -> AnyTransition {
        AnyTransition(ScaleTransition(scale: scale, anchor: anchor))
    }

    public static func modifier<Modifier: ViewModifier>(
        active: Modifier,
        identity: Modifier
    ) -> AnyTransition {
        AnyTransition(ModifierTransition(active: active, identity: identity))
    }

    public static func asymmetric(
        insertion: AnyTransition,
        removal: AnyTransition
    ) -> AnyTransition {
        AnyTransition(AsymmetricTransition(insertion: insertion, removal: removal))
    }

    public func combined(with other: AnyTransition) -> AnyTransition {
        AnyTransition(CombinedAnyTransition(first: self, second: other))
    }

    public func animation(_ animation: Animation?) -> AnyTransition {
        AnyTransition(
            properties: properties,
            animationOverride: animation,
            hasAnimationOverride: true
        ) { content, phase in
            AnyView(
                self.applyTransition(content, phase)
                    .transaction { transaction in
                        if !transaction.disablesAnimations {
                            transaction.animation = animation
                        }
                    }
            )
        }
    }

    func animation(for transaction: Transaction) -> Animation? {
        hasAnimationOverride ? animationOverride : transaction.animation
    }

    func duration(for transaction: Transaction) -> TimeInterval {
        animation(for: transaction)?.estimatedDuration ?? 0
    }
}

private final class AnyTransitionApplier: @unchecked Sendable {
    let apply: @MainActor (AnyView, TransitionPhase) -> AnyView

    init(_ apply: @escaping @MainActor (AnyView, TransitionPhase) -> AnyView) {
        self.apply = apply
    }
}

private struct UnsafeTransition<Value>: @unchecked Sendable {
    var value: Value
}

extension EnvironmentValues {
    /// The transition applied to this view branch.
    @Entry public var transition: AnyTransition = .identity
}

@MainActor
protocol TransitionTraitProvider {
    var transitionTrait: AnyTransition? { get }
}

struct TransitionModifierView<Content: View>: TypeSafeView, TransitionTraitProvider {
    typealias Children = TupleViewChildren1<Content>

    var body: TupleView1<Content>
    var transition: AnyTransition

    var transitionTrait: AnyTransition? {
        transition
    }

    init(content: Content, transition: AnyTransition) {
        body = TupleView1(content)
        self.transition = transition
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(
            backend: backend,
            snapshots: snapshots,
            environment: environment.with(\.transition, transition)
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child0.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let childResult = children.child0.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment.with(\.transition, transition)
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child0.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
    }
}

extension AnyView: TransitionTraitProvider {
    var transitionTrait: AnyTransition? {
        (child as? TransitionTraitProvider)?.transitionTrait
    }
}

@MainActor
func _transitionTrait<V: View>(
    of view: V,
    fallback: AnyTransition = .identity
) -> AnyTransition {
    (view as? TransitionTraitProvider)?.transitionTrait ?? fallback
}

@MainActor
func _optionalTransitionTrait<V: View>(of view: V) -> AnyTransition? {
    (view as? TransitionTraitProvider)?.transitionTrait
}

@MainActor
func _transitionTrait(
    of view: any View,
    fallback: AnyTransition = .identity
) -> AnyTransition {
    (view as? TransitionTraitProvider)?.transitionTrait ?? fallback
}

@MainActor
func _optionalTransitionTrait(of view: any View) -> AnyTransition? {
    (view as? TransitionTraitProvider)?.transitionTrait
}

extension View {
    /// Sets the transition used when this view is inserted or removed.
    public func transition(_ transition: AnyTransition) -> some View {
        TransitionModifierView(content: self, transition: transition)
    }
}
