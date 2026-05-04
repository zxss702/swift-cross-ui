extension View {
    /// Offsets this view by the given horizontal and vertical amounts.
    public func offset(x: Double = 0, y: Double = 0) -> some View {
        OffsetEffectView(content: self, offset: SIMD2(x, y))
    }

    /// Offsets this view by a size.
    public func offset(_ size: ViewSize) -> some View {
        offset(x: size.width, y: size.height)
    }

    /// Scales this view by the given amount.
    public func scaleEffect(_ scale: Double, anchor: UnitPoint = .center) -> some View {
        scaleEffect(x: scale, y: scale, anchor: anchor)
    }

    /// Scales this view by the given horizontal and vertical amounts.
    public func scaleEffect(
        x: Double = 1,
        y: Double = 1,
        anchor: UnitPoint = .center
    ) -> some View {
        TransformEffectView(
            content: self,
            transform: .scaling(x: x, y: y),
            anchor: anchor
        )
    }

    /// Rotates this view by the given angle.
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        TransformEffectView(
            content: self,
            transform: .rotation(radians: angle.radians, center: .zero),
            anchor: anchor
        )
    }

    /// Applies an affine transform to this view.
    public func transformEffect(_ transform: AffineTransform) -> some View {
        TransformEffectView(content: self, transform: transform, anchor: .center)
    }

    /// Applies a blur effect to this view.
    public func blur(radius: Double, opaque: Bool = false) -> some View {
        BlurEffectView(content: self, radius: radius, opaque: opaque)
    }

    /// Controls this view's z ordering in containers that support it.
    public func zIndex(_ value: Double) -> some View {
        ZIndexEffectView(content: self, zIndex: value)
    }
}

struct OffsetEffectView<Content: View>: TypeSafeView {
    typealias Children = AnimatableEffectChildren<
        Content,
        AnimatablePair<Double, Double>
    >

    var body: TupleView1<Content>
    var offset: SIMD2<Double>

    init(content: Content, offset: SIMD2<Double>) {
        body = TupleView1(content)
        self.offset = offset
    }

    func children<Backend: BaseAppBackend>(
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

    func asWidget<Backend: BaseAppBackend>(_ children: Children, backend: Backend) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let target = AnimatablePair(offset.x, offset.y)
        children.targetValue = target
        let childResult = children.child.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        let target = AnimatablePair(offset.x, offset.y)
        let presentation = children.animation.value(
            for: target,
            transaction: environment.transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        backend.setPosition(
            ofChildAt: 0,
            in: widget,
            to: Position(presentation.first, presentation.second).vector
        )
    }
}

extension OffsetEffectView: LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.wrapping(Self.self, child: body.view0)
    }
}

struct TransformEffectView<Content: View>: TypeSafeView {
    typealias Children = AnimatableEffectChildren<Content, AffineTransform>

    var body: TupleView1<Content>
    var transform: AffineTransform
    var anchor: UnitPoint

    init(content: Content, transform: AffineTransform, anchor: UnitPoint) {
        body = TupleView1(content)
        self.transform = transform
        self.anchor = anchor
    }

    func children<Backend: BaseAppBackend>(
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

    func asWidget<Backend: BaseAppBackend>(_ children: Children, backend: Backend) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let childResult = children.child.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
        let target = anchoredTransform(in: childResult.size)
        children.targetValue = target
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        let target = anchoredTransform(in: layout.size)
        let presentation = children.animation.value(
            for: target,
            transaction: environment.transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        backend.setTransform(
            of: widget,
            to: presentation
        )
    }

    private func anchoredTransform(in size: ViewSize) -> AffineTransform {
        let anchorPosition = SIMD2(
            x: anchor.x * size.width,
            y: anchor.y * size.height
        )
        return AffineTransform
            .translation(x: -anchorPosition.x, y: -anchorPosition.y)
            .followedBy(transform)
            .followedBy(
                .translation(x: anchorPosition.x, y: anchorPosition.y)
            )
    }
}

extension TransformEffectView: LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.wrapping(Self.self, child: body.view0)
    }
}

struct BlurEffectView<Content: View>: TypeSafeView {
    typealias Children = AnimatableEffectChildren<Content, Double>

    var body: TupleView1<Content>
    var radius: Double
    var opaque: Bool

    init(content: Content, radius: Double, opaque: Bool) {
        body = TupleView1(content)
        self.radius = radius
        self.opaque = opaque
    }

    func children<Backend: BaseAppBackend>(
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

    func asWidget<Backend: BaseAppBackend>(_ children: Children, backend: Backend) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.targetValue = radius
        let childResult = children.child.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
        return ViewLayoutResult(size: childResult.size, childResults: [childResult])
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        let target = radius
        let presentation = children.animation.value(
            for: target,
            transaction: environment.transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        // Kept for SwiftUI source compatibility. Current backend blur APIs do
        // not expose an opaque edge-sampling mode.
        _ = opaque
        backend.setBlur(of: widget, radius: presentation)
    }
}

extension BlurEffectView: LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.wrapping(Self.self, child: body.view0)
    }
}

struct ZIndexEffectView<Content: View>: TypeSafeView {
    typealias Children = TupleViewChildren1<Content>

    var body: TupleView1<Content>
    var zIndex: Double

    init(content: Content, zIndex: Double) {
        body = TupleView1(content)
        self.zIndex = zIndex
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func asWidget<Backend: BaseAppBackend>(_ children: Children, backend: Backend) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.child0.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
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

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.child0.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        backend.setZIndex(of: widget, to: zIndex)
    }
}

extension ZIndexEffectView: LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.wrapping(Self.self, child: body.view0)
    }
}
