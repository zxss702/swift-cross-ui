@MainActor
enum TransitionRuntime {
    final class RemovalToken {
        fileprivate var completion: AnimationRuntime.Completion?
        fileprivate var isCancelled = false

        @MainActor
        func cancel() {
            isCancelled = true
            AnimationRuntime.cancelCompletion(completion)
        }
    }

    static func setInsertionStart<Content: View>(
        node: AnyViewGraphNode<TransitionHost<Content>>,
        content: Content,
        transition: AnyTransition,
        environment: EnvironmentValues
    ) {
        update(
            node: node,
            content: content,
            transition: transition,
            phase: .willAppear,
            environment: environment.with(\.transaction, .disablingAnimations)
        )
    }

    static func animateInsertion<Content: View>(
        node: AnyViewGraphNode<TransitionHost<Content>>,
        content: Content,
        transition: AnyTransition,
        environment: EnvironmentValues
    ) {
        update(
            node: node,
            content: content,
            transition: transition,
            phase: .identity,
            environment: environment
        )
    }

    @discardableResult
    static func animateRemoval<Content: View>(
        node: AnyViewGraphNode<TransitionHost<Content>>,
        content: Content,
        transition: AnyTransition,
        environment: EnvironmentValues,
        onComplete: @escaping @MainActor () -> Void = {}
    ) -> RemovalToken {
        let token = RemovalToken()
        let recorded = AnimationRuntime.recordAnimationWrites {
            update(
                node: node,
                content: content,
                transition: transition,
                phase: .didDisappear,
                environment: environment
            )
        }
        token.completion = AnimationRuntime.trackCompletion(
            keys: recorded.keys,
            completion: { [weak token] in
                guard let token, !token.isCancelled else {
                    return
                }
                onComplete()
            }
        )
        return token
    }

    static func cancelRemoval(_ token: RemovalToken?) {
        token?.cancel()
    }

    private static func update<Content: View>(
        node: AnyViewGraphNode<TransitionHost<Content>>,
        content: Content,
        transition: AnyTransition,
        phase: TransitionPhase,
        environment: EnvironmentValues
    ) {
        let host = TransitionHost(
            content: content,
            transition: transition,
            phase: phase
        )
        _ = node.computeLayout(
            with: host,
            proposedSize: node.lastProposedSize,
            environment: environment
        )
        _ = node.commit()
        node.flushLayout()
    }
}
