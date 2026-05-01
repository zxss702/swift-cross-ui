import Foundation

/// A view that assigns an explicit identity to its content.
public struct IDView<Content: View, ID: Hashable>: TypeSafeView, TransitionTraitProvider {
    typealias Children = IDViewChildren<Content, ID>

    public var body = EmptyView()

    var content: Content
    var id: ID

    var transitionTrait: AnyTransition? {
        (content as? TransitionTraitProvider)?.transitionTrait
    }

    init(content: Content, id: ID) {
        self.content = content
        self.id = id
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children(
            from: self,
            backend: backend,
            snapshot: snapshots?.count == 1 ? snapshots?.first : nil,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: Children,
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

    func commit<Backend: AppBackend>(
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
    fileprivate var dynamicContent: DynamicTransitionContent {
        DynamicTransitionContent(
            identity: DynamicTransitionIdentity(
                type: Content.self,
                id: AnyHashable(id)
            ),
            view: AnyView(content),
            transition: _optionalTransitionTrait(of: content) ?? .opacity,
            canTransition: true
        )
    }
}

class IDViewChildren<Content: View, ID: Hashable>: ViewGraphNodeChildren {
    var state: DynamicTransitionState

    var widgets: [AnyWidget] {
        state.widgets
    }

    var erasedNodes: [ErasedViewGraphNode] {
        state.erasedNodes
    }

    init<Backend: AppBackend>(
        from view: IDView<Content, ID>,
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

extension View {
    /// Binds a view's identity to the given hashable value.
    public func id<ID: Hashable>(_ id: ID) -> some View {
        IDView(content: self, id: id)
    }
}
