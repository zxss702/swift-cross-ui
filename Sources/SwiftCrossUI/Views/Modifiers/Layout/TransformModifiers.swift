extension View {
    public func scaleEffect(_ scale: Double) -> some View {
        scaleEffect(scale, anchor: .center)
    }

    public func scaleEffect(_ scale: Double, anchor: UnitPoint) -> some View {
        scaleEffect(x: scale, y: scale, anchor: anchor)
    }

    public func scaleEffect(
        x: Double = 1,
        y: Double = 1,
        anchor: UnitPoint = .center
    ) -> some View {
        TransformModifier(
            self,
            transform: ViewTransform(
                scale: SIMD2(x, y),
                translation: .zero,
                rotation: .zero,
                anchor: anchor
            )
        )
    }

    public func offset(x: Double = 0, y: Double = 0) -> some View {
        TransformModifier(
            self,
            transform: ViewTransform(
                scale: SIMD2(1, 1),
                translation: SIMD2(x, y),
                rotation: .zero,
                anchor: .center
            )
        )
    }

    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        TransformModifier(
            self,
            transform: ViewTransform(
                scale: SIMD2(1, 1),
                translation: .zero,
                rotation: angle,
                anchor: anchor
            )
        )
    }
}

private struct TransformModifier<Child: View>: TypeSafeView {
    var body: TupleView1<Child>
    var transform: ViewTransform

    init(_ child: Child, transform: ViewTransform) {
        body = TupleView1(child)
        self.transform = transform
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
        AnimationRuntime.setTransform(
            of: widget,
            to: transform,
            environment: environment,
            backend: backend,
            bounds: layout.size.vector
        )
    }
}
