extension View {
    /// Sets the transparency of this view.
    public func opacity(_ opacity: Double) -> some View {
        OpacityEffectView(content: self, opacity: opacity)
    }
}

struct OpacityEffectView<Content: View>: TypeSafeView {
    typealias Children = AnimatableEffectChildren<Content, Double>

    var body: TupleView1<Content>
    var opacity: Double

    init(content: Content, opacity: Double) {
        body = TupleView1(content)
        self.opacity = opacity
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children(
            content: body.view0,
            backend: backend,
            snapshots: snapshots,
            environment: environment
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
        children.targetValue = opacity
        let childResult = children.child.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
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
        let target = children.targetValue ?? opacity
        let presentation = children.animation.value(
            for: target,
            transaction: environment.transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        backend.setOpacity(of: widget, to: presentation)
    }
}
