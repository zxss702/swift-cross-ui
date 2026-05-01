import Foundation

@MainActor
final class DynamicTransitionState {
    var activeNode: ErasedViewGraphNode?
    var activeContent: DynamicTransitionContent?
    var activePhase: TransitionPhase = .identity
    var removalNode: ErasedViewGraphNode?
    var removalContent: DynamicTransitionContent?
    var proposedSize = ProposedViewSize.zero
    var widgetNeedsRebuild = false
    var removalIsScheduled = false
    var removalGeneration = 0
    var hasMounted = false

    var widgets: [AnyWidget] {
        [removalNode, activeNode].compactMap { $0?.getWidget() }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [removalNode, activeNode].compactMap { $0 }
    }

    func update<Backend: AppBackend>(
        content: DynamicTransitionContent?,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        self.proposedSize = proposedSize

        guard let content else {
            return updateToEmpty(
                proposedSize: proposedSize,
                environment: environment
            )
        }

        if removalContent?.identity == content.identity, activeNode == nil {
            activeNode = removalNode
            activeContent = content
            removalNode = nil
            removalContent = nil
            removalIsScheduled = false
            activePhase = .identity
            widgetNeedsRebuild = true
        }

        if activeContent?.identity != content.identity {
            moveActiveNodeToRemovalIfNeeded(environment: environment)
            let initialPhase = insertionPhase(for: content, environment: environment)
            activePhase = initialPhase
            activeNode = ErasedViewGraphNode(
                for: renderedView(for: content, phase: initialPhase),
                backend: backend,
                environment: environment
            )
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

    func commit<Backend: AppBackend>(
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

        _ = removalNode?.commit()
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
            removalNode = node
            removalContent = content
            removalIsScheduled = false
            removalGeneration += 1
        } else {
            removalNode = nil
            removalContent = nil
            removalIsScheduled = false
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
        guard let removalNode, let removalContent else {
            return nil
        }

        return removalNode.computeLayoutWithNewView(
            renderedView(for: removalContent, phase: .didDisappear),
            proposedSize,
            transitionEnvironment(for: removalContent, environment: environment)
        ).size
    }

    private func scheduleRemovalIfNeeded<Backend: AppBackend>(
        widget: Backend.Widget,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard removalNode != nil, !removalIsScheduled, let content = removalContent else {
            return
        }

        removalIsScheduled = true
        let generation = removalGeneration
        let duration = transitionDuration(for: content, environment: environment)
        let remove: @MainActor @Sendable () -> Void = {
            guard self.removalGeneration == generation else {
                return
            }
            self.removalNode = nil
            self.removalContent = nil
            self.removalIsScheduled = false
            self.widgetNeedsRebuild = true
            self.requestGraphUpdate(environment: environment, backend: backend)
        }

        guard duration > 0 else {
            remove()
            return
        }

        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread {
                remove()
            }
            return
        }

        graphUpdateHost.enqueueAfter(
            backend: backend,
            delay: duration,
            transaction: environment.transaction,
            key: AnyHashable(ObjectIdentifier(self)),
            action: remove
        )
    }

    private func scheduleInsertionUpdateIfNeeded<Backend: AppBackend>(
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

    private func requestGraphUpdate<Backend: AppBackend>(
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
