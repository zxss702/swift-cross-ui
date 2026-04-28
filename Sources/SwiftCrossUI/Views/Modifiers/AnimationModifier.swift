extension View {
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View {
        EnvironmentModifier(self) { environment in
            var environment = environment
            transform(&environment.transaction)
            return environment
        }
    }

    public func transaction<Value: Equatable>(
        value: Value,
        _ transform: @escaping (inout Transaction) -> Void
    ) -> some View {
        TransactionValueModifier(self, value: value, transform: transform)
    }

    public func animation(_ animation: Animation?) -> some View {
        transaction { transaction in
            guard !transaction.disablesAnimations else {
                return
            }
            guard !transaction.isExplicit else {
                return
            }
            transaction.animation = animation
            transaction.disablesAnimations = animation == nil
        }
    }

    public func animation(_ animation: Animation = .default) -> some View {
        self.animation(Optional(animation))
    }

    public func animation<Value: Equatable>(
        _ animation: Animation?,
        value: Value
    ) -> some View {
        AnimationValueModifier(
            self,
            animation: animation,
            value: value
        )
    }

    public func animation<Value: Equatable>(
        _ animation: Animation = .default,
        value: Value
    ) -> some View {
        self.animation(Optional(animation), value: value)
    }
}

private struct TransactionValueModifier<Child: View, Value: Equatable>: TypeSafeView {
    var body: TupleView1<Child>
    var value: Value
    var transform: (inout Transaction) -> Void

    init(
        _ child: Child,
        value: Value,
        transform: @escaping (inout Transaction) -> Void
    ) {
        body = TupleView1(child)
        self.value = value
        self.transform = transform
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> TransactionValueModifierChildren<Child, Value> {
        TransactionValueModifierChildren(
            child: body.view0,
            backend: backend,
            snapshots: snapshots,
            environment: environment,
            initialValue: value
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: TransactionValueModifierChildren<Child, Value>,
        backend: Backend
    ) -> Backend.Widget {
        children.childNode.widget.into()
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TransactionValueModifierChildren<Child, Value>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.updateTransaction(value: value, transform: transform, base: environment.transaction)
        return children.childNode.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment.with(\.transaction, children.transaction)
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TransactionValueModifierChildren<Child, Value>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.childNode.commit()
        children.previousValue = value
    }
}

private final class TransactionValueModifierChildren<Child: View, Value: Equatable>:
    ViewGraphNodeChildren
{
    var childNode: AnyViewGraphNode<Child>
    var previousValue: Value
    var transaction: Transaction

    var widgets: [AnyWidget] {
        [childNode.widget]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: childNode)]
    }

    init<Backend: AppBackend>(
        child: Child,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues,
        initialValue: Value
    ) {
        childNode = AnyViewGraphNode(
            for: child,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
        previousValue = initialValue
        transaction = environment.transaction
    }

    func updateTransaction(
        value: Value,
        transform: (inout Transaction) -> Void,
        base: Transaction
    ) {
        transaction = base
        guard value != previousValue else {
            return
        }
        transform(&transaction)
    }
}

private struct AnimationValueModifier<Child: View, Value: Equatable>: TypeSafeView {
    var body: TupleView1<Child>
    var animation: Animation?
    var value: Value

    init(_ child: Child, animation: Animation?, value: Value) {
        body = TupleView1(child)
        self.animation = animation
        self.value = value
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> AnimationValueModifierChildren<Child, Value> {
        AnimationValueModifierChildren(
            child: body.view0,
            backend: backend,
            snapshots: snapshots,
            environment: environment,
            initialValue: value
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: AnimationValueModifierChildren<Child, Value>,
        backend: Backend
    ) -> Backend.Widget {
        children.childNode.widget.into()
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: AnimationValueModifierChildren<Child, Value>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.updateTransaction(
            value: value,
            animation: animation,
            base: environment.transaction
        )

        return children.childNode.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment.with(\.transaction, children.transaction)
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: AnimationValueModifierChildren<Child, Value>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.childNode.commit()
        children.commitValue(value)
    }
}

private final class AnimationValueModifierChildren<Child: View, Value: Equatable>:
    ViewGraphNodeChildren
{
    var childNode: AnyViewGraphNode<Child>
    var previousValue: Value
    var pendingValue: Value
    var transaction: Transaction

    var widgets: [AnyWidget] {
        [childNode.widget]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: childNode)]
    }

    init<Backend: AppBackend>(
        child: Child,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues,
        initialValue: Value
    ) {
        childNode = AnyViewGraphNode(
            for: child,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
        previousValue = initialValue
        pendingValue = initialValue
        transaction = environment.transaction
    }

    func updateTransaction(value: Value, animation: Animation?, base: Transaction) {
        pendingValue = value
        transaction = base

        guard value != previousValue else {
            return
        }

        guard !base.disablesAnimations else {
            return
        }

        guard !base.isExplicit else {
            return
        }

        transaction.animation = animation
        transaction.disablesAnimations = animation == nil
    }

    func commitValue(_ value: Value) {
        previousValue = value
    }
}
