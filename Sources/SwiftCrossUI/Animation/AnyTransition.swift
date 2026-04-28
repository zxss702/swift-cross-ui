/// Indicates which stage of a transition is currently being rendered.
public enum TransitionPhase: Sendable, Equatable {
    /// The view is about to be inserted into the hierarchy.
    case willAppear
    /// The view is in its stable, visible state.
    case identity
    /// The view has been requested to leave the hierarchy.
    case didDisappear

    public var isIdentity: Bool {
        self == .identity
    }

    public var value: Double {
        switch self {
            case .willAppear:
                -1
            case .identity:
                0
            case .didDisappear:
                1
        }
    }
}

/// High level information about a transition.
public struct TransitionProperties: Sendable, Equatable {
    public var hasMotion: Bool

    public init(hasMotion: Bool = true) {
        self.hasMotion = hasMotion
    }

    func union(_ other: TransitionProperties) -> TransitionProperties {
        TransitionProperties(hasMotion: hasMotion || other.hasMotion)
    }
}

/// The content passed to a ``Transition`` body.
///
/// This is a placeholder-like view, matching SwiftUI's transition mental model:
/// a transition is just a set of ordinary view modifiers applied to the same
/// content while its phase changes.
public struct TransitionContent: View {
    public var body: AnyView

    init(_ content: AnyView) {
        body = content
    }

    public func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    public func layoutableChildren<Backend: AppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children as! AnyViewChildren)
    }

    public func asWidget<Backend: AppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children as! AnyViewChildren, backend: backend)
    }

    public func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children as! AnyViewChildren,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    public func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children as! AnyViewChildren,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}

/// A description of changes to apply when a view is added to or removed from
/// the hierarchy.
@MainActor
public protocol Transition {
    associatedtype Body: View
    typealias Content = TransitionContent

    @ViewBuilder func body(content: Content, phase: TransitionPhase) -> Body

    static var properties: TransitionProperties { get }
}

extension Transition {
    public static var properties: TransitionProperties {
        TransitionProperties()
    }

    func apply(content: AnyView, phase: TransitionPhase) -> AnyView {
        AnyView(body(content: TransitionContent(content), phase: phase))
    }

    public func combined<T: Transition>(with other: T) -> some Transition {
        CombiningTransition(transition1: self, transition2: other)
    }

    public func animation(_ animation: Animation?) -> some Transition {
        transaction { transaction, _ in
            transaction.animation = animation
            transaction.disablesAnimations = animation == nil
        }
    }

    func transaction(
        _ modify: @escaping @MainActor (inout Transaction, TransitionPhase) -> Void
    ) -> FilteredTransition<Self> {
        FilteredTransition(transition: self, filter: modify)
    }
}

/// A type-erased transition.
@MainActor
public struct AnyTransition: @unchecked Sendable {
    private let box: AnyTransitionBox
    public let properties: TransitionProperties
    public let isIdentity: Bool

    public init<T: Transition>(_ transition: T) {
        box = TransitionBox(transition)
        properties = T.properties
        isIdentity = box.isIdentity
    }

    public static let identity = AnyTransition(IdentityTransition())
    public static let opacity = AnyTransition(OpacityTransition())
    public static let scale = AnyTransition(ScaleTransition(1e-5))
    public static let slide = AnyTransition(SlideTransition())

    public static func scale(scale: Double) -> AnyTransition {
        AnyTransition(ScaleTransition(scale))
    }

    public static func scale(scale: Double, anchor: UnitPoint) -> AnyTransition {
        AnyTransition(ScaleTransition(scale, anchor: anchor))
    }

    public static func offset(x: Double = 0, y: Double = 0) -> AnyTransition {
        AnyTransition(OffsetTransition(x: x, y: y))
    }

    public static func offset(_ offset: SIMD2<Double>) -> AnyTransition {
        .offset(x: offset.x, y: offset.y)
    }

    public static func move(edge: Edge) -> AnyTransition {
        AnyTransition(MoveTransition(edge: edge))
    }

    public static func push(from edge: Edge) -> AnyTransition {
        AnyTransition(PushTransition(edge: edge))
    }

    public static func modifier<Modifier: ViewModifier>(
        active: Modifier,
        identity: Modifier
    ) -> AnyTransition {
        AnyTransition(ModifierTransition(activeModifier: active, identityModifier: identity))
    }

    public static func asymmetric(
        insertion: AnyTransition,
        removal: AnyTransition
    ) -> AnyTransition {
        AnyTransition(AsymmetricTransition(insertion: insertion, removal: removal))
    }

    public func combined(with other: AnyTransition) -> AnyTransition {
        AnyTransition(CombiningTransition(transition1: self, transition2: other))
    }

    public func animation(_ animation: Animation?) -> AnyTransition {
        AnyTransition(FilteredTransition(transition: self) { transaction, _ in
            transaction.animation = animation
            transaction.disablesAnimations = animation == nil
        })
    }

    func apply(content: AnyView, phase: TransitionPhase) -> AnyView {
        box.apply(content: content, phase: phase)
    }
}

extension AnyTransition: Transition {
    public func body(content: Content, phase: TransitionPhase) -> AnyView {
        return apply(content: AnyView(content), phase: phase)
    }
}

@MainActor
private class AnyTransitionBox {
    var isIdentity: Bool {
        false
    }

    func apply(content: AnyView, phase: TransitionPhase) -> AnyView {
        fatalError("abstract transition box")
    }
}

@MainActor
private final class TransitionBox<Base: Transition>: AnyTransitionBox {
    var transition: Base

    init(_ transition: Base) {
        self.transition = transition
    }

    override var isIdentity: Bool {
        Base.self == IdentityTransition.self
    }

    override func apply(content: AnyView, phase: TransitionPhase) -> AnyView {
        transition.apply(content: content, phase: phase)
    }
}

public struct IdentityTransition: Transition, Sendable {
    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> Content {
        return content
    }

    public static let properties = TransitionProperties(hasMotion: false)

}

extension Transition where Self == IdentityTransition {
    public static var identity: IdentityTransition {
        IdentityTransition()
    }
}

struct ModifierTransition<Modifier: ViewModifier>: Transition {
    var activeModifier: Modifier
    var identityModifier: Modifier

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(phase.isIdentity ? identityModifier : activeModifier)
    }
}

struct CombiningTransition<First: Transition, Second: Transition>: Transition {
    var transition1: First
    var transition2: Second

    func body(content: Content, phase: TransitionPhase) -> AnyView {
        return transition2.apply(
            content: transition1.apply(content: AnyView(content), phase: phase),
            phase: phase
        )
    }

    static var properties: TransitionProperties {
        First.properties.union(Second.properties)
    }

}

public struct AsymmetricTransition<Insertion: Transition, Removal: Transition>: Transition {
    public var insertion: Insertion
    public var removal: Removal

    public init(insertion: Insertion, removal: Removal) {
        self.insertion = insertion
        self.removal = removal
    }

    public func body(content: Content, phase: TransitionPhase) -> AnyView {
        return removal.apply(
            content: insertion.apply(
                content: AnyView(content),
                phase: phase == .didDisappear ? .identity : phase
            ),
            phase: phase == .didDisappear ? phase : .identity
        )
    }

    public static var properties: TransitionProperties {
        Insertion.properties.union(Removal.properties)
    }

}

struct FilteredTransition<Base: Transition>: Transition {
    var transition: Base
    var filter: @MainActor (inout Transaction, TransitionPhase) -> Void

    func body(content: Content, phase: TransitionPhase) -> some View {
        transition
            .apply(content: AnyView(content), phase: phase)
            .transaction { transaction in
                filter(&transaction, phase)
            }
    }

    static var properties: TransitionProperties {
        Base.properties
    }

}

public struct OpacityTransition: Transition, Sendable {
    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.opacity(phase.isIdentity ? 1 : 0)
    }

    public static let properties = TransitionProperties(hasMotion: false)

}

extension Transition where Self == OpacityTransition {
    public static var opacity: OpacityTransition {
        OpacityTransition()
    }
}

public struct ScaleTransition: Transition, Sendable {
    public var scale: Double
    public var anchor: UnitPoint

    public init(_ scale: Double = 1e-5, anchor: UnitPoint = .center) {
        self.scale = scale
        self.anchor = anchor
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.scaleEffect(phase.isIdentity ? 1 : scale, anchor: anchor)
    }

}

extension Transition where Self == ScaleTransition {
    public static var scale: ScaleTransition {
        ScaleTransition()
    }

    public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> ScaleTransition {
        ScaleTransition(scale, anchor: anchor)
    }
}

public struct OffsetTransition: Transition, Sendable {
    public var offset: SIMD2<Double>

    public init(_ offset: SIMD2<Double>) {
        self.offset = offset
    }

    public init(x: Double = 0, y: Double = 0) {
        self.offset = SIMD2(x, y)
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.offset(
            x: phase.isIdentity ? 0 : offset.x,
            y: phase.isIdentity ? 0 : offset.y
        )
    }
}

extension Transition where Self == OffsetTransition {
    public static func offset(_ offset: SIMD2<Double>) -> OffsetTransition {
        OffsetTransition(offset)
    }

    public static func offset(x: Double = 0, y: Double = 0) -> OffsetTransition {
        OffsetTransition(x: x, y: y)
    }
}

public struct MoveTransition: Transition, Sendable {
    public var edge: Edge

    public init(edge: Edge) {
        self.edge = edge
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(MoveTransitionModifier(edge: phase.isIdentity ? nil : edge))
    }

}

extension Transition where Self == MoveTransition {
    public static func move(edge: Edge) -> MoveTransition {
        MoveTransition(edge: edge)
    }
}

public struct SlideTransition: Transition, Sendable {
    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        let edge: Edge? =
            switch phase {
                case .willAppear:
                    .leading
                case .identity:
                    nil
                case .didDisappear:
                    .trailing
            }
        content.modifier(MoveTransitionModifier(edge: edge))
    }

}

extension Transition where Self == SlideTransition {
    public static var slide: SlideTransition {
        SlideTransition()
    }
}

public struct PushTransition: Transition, Sendable {
    public var edge: Edge

    public init(edge: Edge) {
        self.edge = edge
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .modifier(MoveTransitionModifier(edge: moveEdge(for: phase)))
            .opacity(phase.isIdentity ? 1 : 0)
    }

    private func moveEdge(for phase: TransitionPhase) -> Edge? {
        switch phase {
            case .willAppear:
                return edge
            case .identity:
                return nil
            case .didDisappear:
                return edge.opposite
        }
    }
}

extension Transition where Self == PushTransition {
    public static func push(from edge: Edge) -> PushTransition {
        PushTransition(edge: edge)
    }
}

private struct OffsetTransitionModifier: ViewModifier, Sendable, Equatable {
    var x: Double
    var y: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(x, y) }
        set {
            x = newValue.first
            y = newValue.second
        }
    }

    func body(content: Content) -> some View {
        content.offset(x: x, y: y)
    }
}

private struct MoveTransitionModifier: ViewModifier, Sendable, Equatable {
    var edge: Edge?

    func body(content: Content) -> some View {
        MoveTransitionView(content: content, edge: edge)
    }
}

private struct MoveTransitionView<Child: View>: TypeSafeView {
    var body: TupleView1<Child>
    var edge: Edge?

    init(content: Child, edge: Edge?) {
        body = TupleView1(content)
        self.edge = edge
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> TupleViewChildren1<Child> {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func asWidget<Backend: AppBackend>(
        _ children: TupleViewChildren1<Child>,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child0.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TupleViewChildren1<Child>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let childResult = children.child0.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TupleViewChildren1<Child>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let childResult = children.child0.commit()
        AnimationRuntime.setFrame(
            ofChildAt: 0,
            in: widget,
            child: children.child0.widget.into(),
            to: ViewFrame(origin: .zero, size: childResult.size.vector),
            environment: environment,
            backend: backend
        )
        AnimationRuntime.setSize(
            of: widget,
            to: layout.size.vector,
            environment: environment,
            backend: backend
        )
        AnimationRuntime.setTransform(
            of: widget,
            to: ViewTransform(
                scale: SIMD2(1, 1),
                translation: offset(for: layout.size),
                rotation: .zero,
                anchor: .center
            ),
            environment: environment,
            backend: backend,
            bounds: layout.size.vector
        )
    }

    private func offset(for size: ViewSize) -> SIMD2<Double> {
        SIMD2(
            xOffset(width: size.width),
            yOffset(height: size.height)
        )
    }

    private func xOffset(width: Double) -> Double {
        switch edge {
            case .leading:
                -width
            case .trailing:
                width
            case .top, .bottom, nil:
                0
        }
    }

    private func yOffset(height: Double) -> Double {
        switch edge {
            case .top:
                -height
            case .bottom:
                height
            case .leading, .trailing, nil:
                0
        }
    }
}

private extension Edge {
    var opposite: Edge {
        switch self {
            case .top:
                .bottom
            case .bottom:
                .top
            case .leading:
                .trailing
            case .trailing:
                .leading
        }
    }
}

extension View {
    public func transition(_ transition: AnyTransition) -> some View {
        preference(key: \.transition, value: transition)
    }

    public func transition<T: Transition>(_ transition: T) -> some View {
        self.transition(AnyTransition(transition))
    }
}

struct TransitionHost<Content: View>: View {
    var content: Content
    var transition: AnyTransition
    var phase: TransitionPhase

    var body: AnyView {
        return transition.apply(content: AnyView(content), phase: phase)
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func layoutableChildren<Backend: AppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children as! AnyViewChildren)
    }

    func asWidget<Backend: AppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children as! AnyViewChildren, backend: backend)
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children as! AnyViewChildren,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children as! AnyViewChildren,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}
