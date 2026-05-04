/// A view used by ``ViewBuilder`` to support non-exhaustive if statements.
public struct OptionalView<V: View> {
    public var body = EmptyView()

    var view: V?

    /// Wraps an optional view.
    init(_ view: V?) {
        self.view = view
    }
}

extension OptionalView: View {}

extension OptionalView: TypeSafeView {
    typealias Children = OptionalViewChildren<V>

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children(
            from: view,
            backend: backend,
            snapshot: snapshots?.count == 1 ? snapshots?.first : nil,
            environment: environment
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: OptionalViewChildren<V>,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        for (index, child) in children.widgets.enumerated() {
            backend.insert(child.into(), into: container, at: index)
            backend.setPosition(ofChildAt: index, in: container, to: .zero)
        }
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
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

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
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
    fileprivate var dynamicContent: DynamicTransitionContent? {
        guard let view else {
            return nil
        }
        return DynamicTransitionContent(
            identity: DynamicTransitionIdentity(type: V.self),
            view: AnyView(view),
            transition: _optionalTransitionTrait(of: view) ?? .opacity,
            canTransition: true
        )
    }
}

class OptionalViewChildren<V: View>: ViewGraphNodeChildren {
    var state: DynamicTransitionState

    var widgets: [AnyWidget] {
        state.widgets
    }

    var erasedNodes: [ErasedViewGraphNode] {
        state.erasedNodes
    }

    /// Creates storage for an optional view's child if present (which can change at
    /// any time).
    init<Backend: BaseAppBackend>(
        from view: V?,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        state = DynamicTransitionState()
        guard let view else {
            return
        }
        let content = DynamicTransitionContent(
            identity: DynamicTransitionIdentity(type: V.self),
            view: AnyView(view),
            transition: _optionalTransitionTrait(of: view) ?? .opacity,
            canTransition: true
        )
        state.activeContent = content
        state.activeNode = ErasedViewGraphNode(
            for: content.transition.applyTransition(content.view, .identity),
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}
