/// A view that clips its content to the given shape.
///
/// Clipping is implemented through the backend's corner-radius support:
/// backends can clip any rounded rectangle, so `Rectangle`,
/// `RoundedRectangle`, `Capsule`, `Circle` and `Ellipse` are all expressible
/// (capsules, circles and ellipses map to the largest supported radius).
/// More exotic shapes currently fall back to no clipping.
struct ClipShapeView<Content: View>: View, TypeSafeView {
    var content: Content
    var shape: any Shape

    var body: TupleView1<Content> { TupleView1(content) }

    typealias Children = TupleView1<Content>.Children

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    @CastBackend<BackendFeatures.CornerRadius>(returnsWidget: true)
    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        backend.createCornerRadiusContainer(wrapping: body.asWidget(children, backend: backend))
    }

    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: Children
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children)
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    /// The corner radius which approximates `shape` within a view of the
    /// given size, or `nil` when the shape can't be expressed as a clip.
    func clipRadius(size: ViewSize) -> Int? {
        switch shape {
        case is Rectangle:
            return 0
        case let roundedRectangle as RoundedRectangle:
            return Int(roundedRectangle.cornerRadius)
        case is Capsule, is Circle, is Ellipse:
            return LayoutSystem.roundSize(min(size.width, size.height) / 2)
        default:
            return nil
        }
    }

    @CastBackend<BackendFeatures.CornerRadius>
    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let size = children.child0.commit().size
        backend.setSize(of: widget, to: size.vector)
        if let radius = clipRadius(size: size) {
            backend.setCornerRadius(of: widget, to: radius)
        }
    }
}

/// A view that stores a hit-testing shape for its content.
struct ContentShapeView<Content: View>: View, TypeSafeView {
    var content: Content
    var shape: any Shape

    var body: TupleView1<Content> { TupleView1(content) }

    typealias Children = TupleView1<Content>.Children

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children, backend: backend)
    }

    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: Children
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children)
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}

/// A view that stores a mask view for its content.
struct MaskView<Content: View>: View, TypeSafeView {
    var content: Content
    var mask: AnyView

    var body: TupleView1<Content> { TupleView1(content) }

    typealias Children = TupleView1<Content>.Children

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children, backend: backend)
    }

    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: Children
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children)
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}

extension View {
    /// Clips the view to the given shape.
    ///
    /// The shape is recorded on the view; clipping in backends is pending.
    public func clipShape(_ shape: some Shape) -> some View {
        ClipShapeView(content: self, shape: shape)
    }

    /// Clips the view to its bounding rectangle.
    ///
    /// Equivalent to `clipShape(Rectangle())`; clipping in backends is pending.
    public func clipped(antialiased: Bool = false) -> some View {
        clipShape(Rectangle())
    }

    /// Defines the shape used for hit-testing this view.
    ///
    /// The shape is recorded on the view; shaped hit-testing in backends is
    /// pending (views currently hit-test their full bounds).
    public func contentShape(_ shape: some Shape) -> some View {
        ContentShapeView(content: self, shape: shape)
    }

    /// Masks the view using the alpha channel of the given view.
    ///
    /// The mask is recorded on the view; masking in backends is pending.
    public func mask(_ mask: some View) -> some View {
        MaskView(content: self, mask: AnyView(mask))
    }

    /// Masks the view using the alpha channel of the view built by the given
    /// closure, as in SwiftUI.
    public func mask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        MaskView(content: self, mask: AnyView(mask()))
    }

    /// Groups the view's contents so that layer-level effects apply to the
    /// group rather than to individual elements, as in SwiftUI.
    ///
    /// Currently recorded for backend consumption; backends don't flatten
    /// compositing groups yet.
    public func compositingGroup() -> some View {
        self
    }

    /// Rasterizes the view's contents into a single drawing group, as in
    /// SwiftUI.
    ///
    /// Currently a no-op; backends don't rasterize drawing groups yet.
    public func drawingGroup() -> some View {
        self
    }
}
