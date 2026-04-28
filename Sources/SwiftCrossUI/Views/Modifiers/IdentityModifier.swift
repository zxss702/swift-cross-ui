extension View {
    public func id<ID: Hashable>(_ id: ID) -> some View {
        IdentityModifier(self, id: AnyHashable(id))
    }
}

private struct IdentityModifier<Child: View>: TypeSafeView {
    var body: TupleView1<Child>
    var id: AnyHashable

    init(_ child: Child, id: AnyHashable) {
        body = TupleView1(child)
        self.id = id
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> IdentityModifierChildren<Child> {
        IdentityModifierChildren(
            child: body.view0,
            id: id,
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: IdentityModifierChildren<Child>,
        backend: Backend
    ) -> Backend.Widget {
        backend.createContainer()
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: IdentityModifierChildren<Child>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        if children.id != id {
            children.outgoingNode = children.node
            children.node = AnyViewGraphNode(
                for: TransitionHost(
                    content: body.view0,
                    transition: children.transition,
                    phase: .identity
                ),
                backend: backend,
                environment: environment
            )
            children.id = id
            children.hasChangedIdentity = true
        }

        let result = children.node.computeLayout(
            with: TransitionHost(
                content: body.view0,
                transition: children.transition,
                phase: .identity
            ),
            proposedSize: proposedSize,
            environment: environment
        )
        if let transition = result.preferences.transition {
            children.transition = transition
        }
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: IdentityModifierChildren<Child>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let didChangeIdentity = children.hasChangedIdentity
        let didInsertInitial = children.needsInitialInsertion
        let transition = layout.preferences.transition ?? children.transition
        if didInsertInitial {
            backend.removeAllChildren(of: widget)
            _ = children.node.commit()
            backend.insert(children.node.widget.into(), into: widget, at: 0)
            AnimationRuntime.setPosition(
                ofChildAt: 0,
                in: widget,
                to: .zero,
                environment: environment,
                backend: backend
            )
            children.needsInitialInsertion = false
            children.hasChangedIdentity = false
            children.outgoingNode = nil
        } else if didChangeIdentity {
            backend.removeAllChildren(of: widget)
            if let outgoingNode = children.outgoingNode {
                backend.insert(outgoingNode.widget.into(), into: widget, at: 0)
                _ = outgoingNode.commit()
                AnimationRuntime.setPosition(
                    ofChildAt: 0,
                    in: widget,
                    to: .zero,
                    environment: environment,
                    backend: backend
                )
                children.removalToken = TransitionRuntime.animateRemoval(
                    node: outgoingNode,
                    content: outgoingNode.getView().content,
                    transition: transition,
                    environment: environment
                ) { [weak children] in
                    guard let children, children.outgoingNode === outgoingNode else {
                        return
                    }
                    outgoingNode.resetAnimationPresentationRecursively()
                    backend.removeAllChildren(of: widget)
                    backend.insert(children.node.widget.into(), into: widget, at: 0)
                    AnimationRuntime.setPosition(
                        ofChildAt: 0,
                        in: widget,
                        to: .zero,
                        environment: environment,
                        backend: backend
                    )
                    children.outgoingNode = nil
                    children.removalToken = nil
                }
            }

            let index = children.outgoingNode == nil ? 0 : 1
            _ = children.node.commit()
            TransitionRuntime.setInsertionStart(
                node: children.node,
                content: children.node.getView().content,
                transition: transition,
                environment: environment
            )
            backend.insert(children.node.widget.into(), into: widget, at: index)
            AnimationRuntime.setPosition(
                ofChildAt: index,
                in: widget,
                to: .zero,
                environment: environment,
                backend: backend
            )
            TransitionRuntime.animateInsertion(
                node: children.node,
                content: children.node.getView().content,
                transition: transition,
                environment: environment
            )

            children.hasChangedIdentity = false
        }

        if !didChangeIdentity && !didInsertInitial {
            _ = children.node.commit()
        }

        AnimationRuntime.setSize(
            of: widget,
            to: layout.size.vector,
            environment: environment,
            backend: backend
        )
    }
}

private final class IdentityModifierChildren<Child: View>: ViewGraphNodeChildren {
    var node: AnyViewGraphNode<TransitionHost<Child>>
    var outgoingNode: AnyViewGraphNode<TransitionHost<Child>>?
    var removalToken: TransitionRuntime.RemovalToken?
    var id: AnyHashable
    var needsInitialInsertion = true
    var hasChangedIdentity = false
    var transition: AnyTransition = .identity

    var widgets: [AnyWidget] {
        [outgoingNode?.widget, node.widget].compactMap { $0 }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        var nodes: [ErasedViewGraphNode] = []
        if let outgoingNode {
            nodes.append(ErasedViewGraphNode(wrapping: outgoingNode))
        }
        nodes.append(ErasedViewGraphNode(wrapping: node))
        return nodes
    }

    init<Backend: AppBackend>(
        child: Child,
        id: AnyHashable,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        self.node = AnyViewGraphNode(
            for: TransitionHost(
                content: child,
                transition: .identity,
                phase: .identity
            ),
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
        self.id = id
    }
}
