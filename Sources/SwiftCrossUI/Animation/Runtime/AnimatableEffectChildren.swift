@MainActor
final class AnimatableEffectChildren<Content: View, Value: VectorArithmetic>:
    ViewGraphNodeChildren
{
    let child: AnyViewGraphNode<Content>
    let animation = PresentationAnimation<Value>()
    var targetValue: Value?

    var widgets: [AnyWidget] {
        [child.widget]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: child)]
    }

    init<Backend: BaseAppBackend>(
        content: Content,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        child = AnyViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }
}
