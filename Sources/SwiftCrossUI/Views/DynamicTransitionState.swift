import Foundation

@MainActor
final class DynamicTransitionState {
    var activeNode: ErasedViewGraphNode?
    var activeContent: DynamicTransitionContent?
    var activePhase: TransitionPhase = .identity
    private var removals: [RemovalTransition] = []
    var widgetNeedsRebuild = false
    var removalGeneration = 0
    var hasMounted = false

    var widgets: [AnyWidget] {
        removals.map { $0.node.getWidget() } + [activeNode].compactMap { $0?.getWidget() }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        removals.map(\.node) + [activeNode].compactMap { $0 }
    }

    func update<Backend: BaseAppBackend>(
        content: DynamicTransitionContent?,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        guard let content else {
            return updateToEmpty(
                proposedSize: proposedSize,
                environment: environment
            )
        }

        if activeContent?.identity != content.identity {
            let revivedRemoval = removals
                .lastIndex { $0.content.identity == content.identity }
                .map { removals.remove(at: $0) }
            moveActiveNodeToRemovalIfNeeded(environment: environment)
            if let revivedRemoval {
                activeNode = revivedRemoval.node
                activePhase = .identity
            } else {
                let initialPhase = insertionPhase(for: content, environment: environment)
                activePhase = initialPhase
                activeNode = ErasedViewGraphNode(
                    for: renderedView(for: content, phase: initialPhase),
                    backend: backend,
                    environment: environment
                )
            }
            activeContent = content
            widgetNeedsRebuild = true
        } else {
            activeContent = content
        }

        let (_, result) = activeNode!.computeLayoutWithNewView(
            renderedView(for: content, phase: activePhase),
            proposedSize,
            transitionEnvironment(for: content, environment: environment)
        )

        computeRemovalLayoutIfNeeded(
            proposedSize: proposedSize,
            environment: environment
        )
        return result
    }

    func commit<Backend: BaseAppBackend>(
        widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        if widgetNeedsRebuild {
            backend.removeAllChildren(of: widget)
            for (index, child) in widgets.enumerated() {
                backend.insert(child.into(), into: widget, at: index)
                backend.setPosition(ofChildAt: index, in: widget, to: .zero)
            }
            widgetNeedsRebuild = false
        }

        for removal in removals {
            _ = removal.node.commit()
        }
        _ = activeNode?.commit()

        backend.setSize(of: widget, to: layout.size.vector)
        for index in widgets.indices {
            backend.setPosition(ofChildAt: index, in: widget, to: .zero)
        }

        scheduleRemovalIfNeeded(widget: widget, environment: environment, backend: backend)
        scheduleInsertionUpdateIfNeeded(environment: environment, backend: backend)
        hasMounted = true
    }

    private func updateToEmpty(
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues
    ) -> ViewLayoutResult {
        guard activeNode != nil else {
            if let result = computeRemovalLayoutIfNeeded(
                proposedSize: proposedSize,
                environment: environment
            ) {
                return result
            }
            return .leafView(size: .zero)
        }

        moveActiveNodeToRemovalIfNeeded(environment: environment)
        if let result = computeRemovalLayoutIfNeeded(
            proposedSize: proposedSize,
            environment: environment
        ) {
            return result
        }
        return .leafView(size: .zero)
    }

    private func moveActiveNodeToRemovalIfNeeded(environment: EnvironmentValues) {
        guard let node = activeNode, let content = activeContent else {
            return
        }

        if transitionDuration(for: content, environment: environment) > 0 {
            removalGeneration += 1
            removals.append(
                RemovalTransition(
                    id: removalGeneration,
                    node: node,
                    content: content
                )
            )
        }

        activeNode = nil
        activeContent = nil
        activePhase = .identity
        widgetNeedsRebuild = true
    }

    @discardableResult
    private func computeRemovalLayoutIfNeeded(
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues
    ) -> ViewLayoutResult? {
        guard !removals.isEmpty else {
            return nil
        }

        var result: ViewLayoutResult?
        for removal in removals {
            result = removal.node.computeLayoutWithNewView(
                renderedView(for: removal.content, phase: .didDisappear),
                proposedSize,
                transitionEnvironment(for: removal.content, environment: environment)
            ).size
        }
        return result
    }

    private func scheduleRemovalIfNeeded<Backend: BaseAppBackend>(
        widget: Backend.Widget,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        for index in removals.indices where !removals[index].isScheduled {
            removals[index].isScheduled = true
            let id = removals[index].id
            let content = removals[index].content
            let duration = transitionDuration(for: content, environment: environment)
            let remove: @MainActor @Sendable () -> Void = {
                self.removals.removeAll { $0.id == id }
                self.widgetNeedsRebuild = true
                self.requestGraphUpdate(environment: environment, backend: backend)
            }

            guard duration > 0 else {
                remove()
                continue
            }

            guard let graphUpdateHost = environment.graphUpdateHost else {
                backend.runInMainThread {
                    remove()
                }
                continue
            }

            graphUpdateHost.enqueueAfter(
                backend: backend,
                delay: duration,
                transaction: environment.transaction,
                key: AnyHashable("\(ObjectIdentifier(self)):\(id)"),
                action: remove
            )
        }
    }

    private func scheduleInsertionUpdateIfNeeded<Backend: BaseAppBackend>(
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard activeNode != nil, activePhase == .willAppear else {
            return
        }

        activePhase = .identity
        let transaction = environment.transaction
        requestGraphUpdate(
            environment: environment.withCurrentTransaction(transaction),
            backend: backend
        )
    }

    private func requestGraphUpdate<Backend: BaseAppBackend>(
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let transaction = environment.transaction
        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread {
                withTransaction(transaction) {
                    StateMutationContext.withTransaction(transaction) {
                        environment.onResize(.zero)
                    }
                }
            }
            return
        }

        graphUpdateHost.enqueue(
            backend: backend,
            transaction: transaction,
            key: AnyHashable(ObjectIdentifier(self))
        ) {
            environment.onResize(.zero)
        }
    }

    private func insertionPhase(
        for content: DynamicTransitionContent,
        environment: EnvironmentValues
    ) -> TransitionPhase {
        transitionDuration(for: content, environment: environment) > 0
            ? .willAppear : .identity
    }

    private func transitionDuration(
        for content: DynamicTransitionContent,
        environment: EnvironmentValues
    ) -> TimeInterval {
        guard content.canTransition, hasMounted else {
            return 0
        }
        return content.transition.duration(for: environment.transaction)
    }

    private func renderedView(
        for content: DynamicTransitionContent,
        phase: TransitionPhase
    ) -> AnyView {
        guard content.canTransition else {
            return content.view
        }
        return content.transition.applyTransition(content.view, phase)
    }

    private func transitionEnvironment(
        for content: DynamicTransitionContent,
        environment: EnvironmentValues
    ) -> EnvironmentValues {
        guard content.canTransition else {
            return environment
        }
        var transaction = environment.transaction
        if !transaction.disablesAnimations {
            transaction.animation = content.transition.animation(for: transaction)
        }
        return environment.withCurrentTransaction(transaction)
    }
}

private struct RemovalTransition {
    var id: Int
    var node: ErasedViewGraphNode
    var content: DynamicTransitionContent
    var isScheduled = false
}
