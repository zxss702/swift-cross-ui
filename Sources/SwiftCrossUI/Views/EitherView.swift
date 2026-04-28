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

extension EitherView: View {
}

extension EitherView: TypeSafeView {
    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> NodeChildren {
        return EitherViewChildren(
            from: self,
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: EitherViewChildren<A, B>,
        backend: Backend
    ) -> Backend.Widget {
        return backend.createContainer()
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: EitherViewChildren<A, B>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let result: ViewLayoutResult
        let hasSwitchedCase: Bool
        switch storage {
            case .a(let a):
                switch children.node {
                    case .a(let nodeA):
                        result = nodeA.computeLayout(
                            with: TransitionHost(
                                content: a,
                                transition: children.transition,
                                phase: .identity
                            ),
                            proposedSize: proposedSize,
                            environment: environment
                        )
                        hasSwitchedCase = false
                    case .b:
                        let nodeA = AnyViewGraphNode(
                            for: TransitionHost(
                                content: a,
                                transition: children.transition,
                                phase: .identity
                            ),
                            backend: backend,
                            environment: environment
                        )
                        children.outgoingNode = children.node
                        children.node = .a(nodeA)
                        result = nodeA.computeLayout(
                            with: TransitionHost(
                                content: a,
                                transition: children.transition,
                                phase: .identity
                            ),
                            proposedSize: proposedSize,
                            environment: environment
                        )
                        hasSwitchedCase = true
                }
            case .b(let b):
                switch children.node {
                    case .b(let nodeB):
                        result = nodeB.computeLayout(
                            with: TransitionHost(
                                content: b,
                                transition: children.transition,
                                phase: .identity
                            ),
                            proposedSize: proposedSize,
                            environment: environment
                        )
                        hasSwitchedCase = false
                    case .a:
                        let nodeB = AnyViewGraphNode(
                            for: TransitionHost(
                                content: b,
                                transition: children.transition,
                                phase: .identity
                            ),
                            backend: backend,
                            environment: environment
                        )
                        children.outgoingNode = children.node
                        children.node = .b(nodeB)
                        result = nodeB.computeLayout(
                            with: TransitionHost(
                                content: b,
                                transition: children.transition,
                                phase: .identity
                            ),
                            proposedSize: proposedSize,
                            environment: environment
                        )
                        hasSwitchedCase = true
                }
        }
        children.hasSwitchedCase = children.hasSwitchedCase || hasSwitchedCase
        if let transition = result.preferences.transition {
            children.transition = transition
        }

        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: EitherViewChildren<A, B>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let didSwitchCase = children.hasSwitchedCase
        let didInsertInitial = children.needsInitialInsertion
        let transition = layout.preferences.transition ?? children.transition
        if didInsertInitial {
            backend.removeAllChildren(of: widget)
            _ = children.node.erasedNode.commit()
            backend.insert(children.node.widget.into(), into: widget, at: 0)
            AnimationRuntime.setPosition(
                ofChildAt: 0,
                in: widget,
                to: .zero,
                environment: environment,
                backend: backend
            )
            children.needsInitialInsertion = false
            children.hasSwitchedCase = false
            children.outgoingNode = nil
        } else if didSwitchCase {
            backend.removeAllChildren(of: widget)
            if let outgoingNode = children.outgoingNode {
                backend.insert(outgoingNode.widget.into(), into: widget, at: 0)
                _ = outgoingNode.erasedNode.commit()
                AnimationRuntime.setPosition(
                    ofChildAt: 0,
                    in: widget,
                    to: .zero,
                    environment: environment,
                    backend: backend
                )
                children.removalToken = outgoingNode.animateRemoval(
                    transition: transition,
                    environment: environment
                ) { [weak children] in
                    guard let children, children.outgoingNode?.matches(outgoingNode) == true else {
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
            _ = children.node.erasedNode.commit()
            children.node.setInsertionStart(transition: transition, environment: environment)
            backend.insert(children.node.widget.into(), into: widget, at: index)
            AnimationRuntime.setPosition(
                ofChildAt: index,
                in: widget,
                to: .zero,
                environment: environment,
                backend: backend
            )
            children.node.animateInsertion(transition: transition, environment: environment)
            children.hasSwitchedCase = false
        }

        if !didSwitchCase && !didInsertInitial {
            _ = children.node.erasedNode.commit()
        }

        AnimationRuntime.setSize(
            of: widget,
            to: layout.size.vector,
            environment: environment,
            backend: backend
        )
    }
}

/// Uses an `enum` to store a view graph node for one of two possible child view types.
class EitherViewChildren<A: View, B: View>: ViewGraphNodeChildren {
    /// A view graph node that wraps one of two possible child view types.
    @MainActor
    enum EitherNode {
        case a(AnyViewGraphNode<TransitionHost<A>>)
        case b(AnyViewGraphNode<TransitionHost<B>>)

        /// The widget corresponding to the currently displayed child view.
        var widget: AnyWidget {
            switch self {
                case .a(let node):
                    return node.widget
                case .b(let node):
                    return node.widget
            }
        }

        var erasedNode: ErasedViewGraphNode {
            switch self {
                case .a(let node):
                    return ErasedViewGraphNode(wrapping: node)
                case .b(let node):
                    return ErasedViewGraphNode(wrapping: node)
            }
        }

        func resetAnimationPresentationRecursively() {
            switch self {
                case .a(let node):
                    node.resetAnimationPresentationRecursively()
                case .b(let node):
                    node.resetAnimationPresentationRecursively()
            }
        }

        func setInsertionStart(
            transition: AnyTransition,
            environment: EnvironmentValues
        ) {
            switch self {
                case .a(let node):
                    TransitionRuntime.setInsertionStart(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment
                    )
                case .b(let node):
                    TransitionRuntime.setInsertionStart(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment
                    )
            }
        }

        func animateInsertion(
            transition: AnyTransition,
            environment: EnvironmentValues
        ) {
            switch self {
                case .a(let node):
                    TransitionRuntime.animateInsertion(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment
                    )
                case .b(let node):
                    TransitionRuntime.animateInsertion(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment
                    )
            }
        }

        func animateRemoval(
            transition: AnyTransition,
            environment: EnvironmentValues,
            onComplete: @escaping @MainActor () -> Void
        ) -> TransitionRuntime.RemovalToken {
            switch self {
                case .a(let node):
                    return TransitionRuntime.animateRemoval(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment,
                        onComplete: onComplete
                    )
                case .b(let node):
                    return TransitionRuntime.animateRemoval(
                        node: node,
                        content: node.getView().content,
                        transition: transition,
                        environment: environment,
                        onComplete: onComplete
                    )
            }
        }

        func matches(_ other: EitherNode?) -> Bool {
            guard let other else {
                return false
            }
            switch (self, other) {
                case (.a(let lhs), .a(let rhs)):
                    return lhs === rhs
                case (.b(let lhs), .b(let rhs)):
                    return lhs === rhs
                default:
                    return false
            }
        }
    }

    /// The view graph node for the currently displayed child.
    var node: EitherNode
    /// A node that is currently being removed from the hierarchy.
    var outgoingNode: EitherNode?
    var removalToken: TransitionRuntime.RemovalToken?
    /// The most recent transition advertised by the active child.
    var transition: AnyTransition = .identity
    /// Whether the initial child still needs to be inserted into the container.
    var needsInitialInsertion = true

    /// Tracks whether the view has switched cases since the last non-dryrun update.
    var hasSwitchedCase = false

    var widgets: [AnyWidget] {
        [outgoingNode?.widget, node.widget].compactMap { $0 }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [outgoingNode?.erasedNode, node.erasedNode].compactMap { $0 }
    }

    /// Creates storage for an either view's current child (which can change at any time).
    init<Backend: AppBackend>(
        from view: EitherView<A, B>,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        // TODO: Ensure that this is valid in all circumstances. It should be, given that
        //   we're assuming that the parent view's state was restored from the same snapshot
        //   which should mean that the same EitherView case will be selected (if we assume
        //   that views are pure, which we have to).
        let snapshot = snapshots?.first
        switch view.storage {
            case .a(let a):
                node = .a(
                    AnyViewGraphNode(
                        for: TransitionHost(
                            content: a,
                            transition: .identity,
                            phase: .identity
                        ),
                        backend: backend,
                        snapshot: snapshot,
                        environment: environment
                    )
                )
            case .b(let b):
                node = .b(
                    AnyViewGraphNode(
                        for: TransitionHost(
                            content: b,
                            transition: .identity,
                            phase: .identity
                        ),
                        backend: backend,
                        snapshot: snapshot,
                        environment: environment
                    )
                )
        }
    }
}
