extension View {
    public func opacity(_ opacity: Double) -> some View {
        OpacityModifier(self, opacity: opacity)
    }
}

private struct OpacityModifier<Child: View>: TypeSafeView {
    var body: TupleView1<Child>
    var opacity: Double

    init(_ child: Child, opacity: Double) {
        body = TupleView1(child)
        self.opacity = opacity
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> TupleViewChildren1<Child> {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func asWidget<Backend: AppBackend>(
        _ children: TupleViewChildren1<Child>,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child0.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TupleViewChildren1<Child>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let childResult = children.child0.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: TupleViewChildren1<Child>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let childResult = children.child0.commit()
        AnimationRuntime.setFrame(
            ofChildAt: 0,
            in: widget,
            child: children.child0.widget.into(),
            to: ViewFrame(origin: .zero, size: childResult.size.vector),
            environment: environment,
            backend: backend
        )
        AnimationRuntime.setSize(
            of: widget,
            to: layout.size.vector,
            environment: environment,
            backend: backend
        )
        AnimationRuntime.setOpacity(
            of: widget,
            to: max(0, min(1, opacity)),
            environment: environment,
            backend: backend
        )
    }
}
