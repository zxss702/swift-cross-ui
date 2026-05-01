extension View {
    /// Applies a transaction mutation to this view.
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View {
        EnvironmentModifier(self) { environment in
            environment.applyingTransactionModifier(transform)
        }
    }

    /// Applies an animation when `value` changes.
    public func animation<Value: Equatable>(
        _ animation: Animation?,
        value: Value
    ) -> some View {
        AnimationValueModifierView(content: self, animation: animation, value: value)
    }

    /// Applies an animation to the modifiers created by `body`.
    public func animation<Result: View>(
        _ animation: Animation? = .default,
        @ViewBuilder body: (Self) -> Result
    ) -> some View {
        body(self).transaction { transaction in
            if !transaction.disablesAnimations {
                transaction.animation = animation
            }
        }
    }
}

struct AnimationValueModifierView<Content: View, Value: Equatable>: TypeSafeView {
    typealias Children = AnimationValueModifierChildren<Content, Value>

    var body: TupleView1<Content>
    var animation: Animation?
    var value: Value

    init(content: Content, animation: Animation?, value: Value) {
        body = TupleView1(content)
        self.animation = animation
        self.value = value
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children(
            content: body.view0,
            value: value,
            backend: backend,
            snapshots: snapshots,
            environment: modifiedEnvironment(environment, previousValue: nil)
        )
    }

    func asWidget<Backend: AppBackend>(_ children: Children, backend: Backend) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let viewEnvironment = modifiedEnvironment(
            environment,
            previousValue: children.previousValue
        )
        children.previousValue = value
        let childResult = children.child.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: viewEnvironment
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
    }

    private func modifiedEnvironment(
        _ environment: EnvironmentValues,
        previousValue: Value?
    ) -> EnvironmentValues {
        guard previousValue != nil, previousValue != value else {
            return environment
        }
        var transaction = environment.transaction
        if !transaction.disablesAnimations {
            transaction.animation = animation
        }
        return environment.withCurrentTransaction(transaction)
    }
}

class AnimationValueModifierChildren<Content: View, Value: Equatable>: ViewGraphNodeChildren {
    var child: AnyViewGraphNode<Content>
    var previousValue: Value?

    var widgets: [AnyWidget] {
        [child.widget]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: child)]
    }

    init<Backend: AppBackend>(
        content: Content,
        value: Value,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        previousValue = value
        child = AnyViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }
}
