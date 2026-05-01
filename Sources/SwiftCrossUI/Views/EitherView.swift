/// A view used by ``ViewBuilder`` to support if/else conditional statements.
public struct EitherView<A: View, B: View> {
    typealias NodeChildren = EitherViewChildren<A, B>

    public var body = EmptyView()

    /// Stores one of two possible view types.
    enum Storage {
        case a(A)
        case b(B)
    }

    var storage: Storage

    /// Creates an either view with its first case visible initially.
    init(_ a: A) {
        storage = .a(a)
    }

    /// Creates an either view with its second case visible initially.
    init(_ b: B) {
        storage = .b(b)
    }
}

extension EitherView: View {}

extension EitherView: TypeSafeView {
    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> NodeChildren {
        EitherViewChildren(
            from: self,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: EitherViewChildren<A, B>,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        for (index, child) in children.widgets.enumerated() {
            backend.insert(child.into(), into: container, at: index)
            backend.setPosition(ofChildAt: index, in: container, to: .zero)
        }
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: EitherViewChildren<A, B>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.state.update(
            content: dynamicContent,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: EitherViewChildren<A, B>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        children.state.commit(
            widget: widget,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }

    @MainActor
    fileprivate var dynamicContent: DynamicTransitionContent {
        switch storage {
            case .a(let a):
                DynamicTransitionContent(
                    identity: DynamicTransitionIdentity(
                        type: A.self,
                        id: AnyHashable(0)
                    ),
                    view: AnyView(a),
                    transition: _optionalTransitionTrait(of: a) ?? .opacity,
                    canTransition: true
                )
            case .b(let b):
                DynamicTransitionContent(
                    identity: DynamicTransitionIdentity(
                        type: B.self,
                        id: AnyHashable(1)
                    ),
                    view: AnyView(b),
                    transition: _optionalTransitionTrait(of: b) ?? .opacity,
                    canTransition: true
                )
        }
    }
}

class EitherViewChildren<A: View, B: View>: ViewGraphNodeChildren {
    var state: DynamicTransitionState

    var widgets: [AnyWidget] {
        state.widgets
    }

    var erasedNodes: [ErasedViewGraphNode] {
        state.erasedNodes
    }

    init<Backend: AppBackend>(
        from view: EitherView<A, B>,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        state = DynamicTransitionState()
        let content = view.dynamicContent
        state.activeContent = content
        state.activeNode = ErasedViewGraphNode(
            for: content.transition.applyTransition(content.view, .identity),
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}
