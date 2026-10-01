/// A view that stores a scale transform for its content.
struct ScaleEffectView<Content: View>: View {
    var content: Content
    var scale: CGSize
    var anchor: UnitPoint

    var body: some View {
        content
    }
}

/// Implemented by backend widget types that support rotating their rendered
/// output around a normalized anchor point (0...1 within the widget's bounds).
/// Widgets that don't conform simply render unrotated — the modifier degrades
/// gracefully instead of requiring every backend to opt in.
/// Only ever invoked on the main thread; deliberately *not* `@MainActor` —
/// conforming a backend's widget class to a global-actor protocol would
/// propagate that isolation onto the entire widget class hierarchy.
public protocol SCUIRotatable {
    func setRotation(degrees: Double, anchor: UnitPoint)
}

/// A view that rotates its content around an anchor point.
struct RotationEffectView<Content: View>: View, TypeSafeView {
    var content: Content
    var angle: Angle
    var anchor: UnitPoint

    var body: TupleView1<Content> { TupleView1(content) }

    typealias Children = TupleView1<Content>.Children

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        body.children(
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
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
        children.child0.computeLayout(
            with: body.view0,
            proposedSize: proposedSize,
            environment: environment
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let size = children.child0.commit().size
        backend.setSize(of: widget, to: size.vector)
        (widget as? any SCUIRotatable)?.setRotation(
            degrees: angle.degrees,
            anchor: anchor
        )
    }
}

/// A view that stores an offset for its content.
struct OffsetView<Content: View>: View {
    var content: Content
    var offset: CGSize

    var body: some View {
        content
    }
}

/// A view that stores a blur radius for its content.
struct BlurView<Content: View>: View {
    var content: Content
    var radius: Double

    var body: some View {
        content
    }
}

/// A view that stores an accessibility label for its content.
struct AccessibilityLabelView<Content: View>: View {
    var content: Content
    var label: String

    var body: some View {
        content
    }
}

/// How scroll views bounce along an axis when reaching the end of content.
public enum ScrollBounceBehavior: Sendable {
    /// The system decides based on content and platform.
    case automatic
    /// Always bounce.
    case always
    /// Bounce only when content exceeds the scroll view's size.
    case basedOnSize
}

extension View {
    /// Sets the transparency of the view.
    ///
    /// The value is carried through the environment; backends apply it to
    /// views when opacity support lands.
    public func opacity(_ opacity: Double) -> some View {
        environment(\.viewOpacity, opacity)
    }

    /// Scales the view's rendered output by the given amount.
    ///
    /// The transform is recorded on the view; transform rendering in
    /// backends is pending.
    public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View {
        ScaleEffectView(content: self, scale: scale, anchor: anchor)
    }

    /// Scales the view's rendered output uniformly.
    ///
    /// The transform is recorded on the view; transform rendering in
    /// backends is pending.
    public func scaleEffect(_ scale: Double, anchor: UnitPoint = .center) -> some View {
        scaleEffect(CGSize(width: scale, height: scale), anchor: anchor)
    }

    /// Scales the view's rendered output along each axis.
    ///
    /// The transform is recorded on the view; transform rendering in
    /// backends is pending.
    public func scaleEffect(x: Double = 1, y: Double = 1, anchor: UnitPoint = .center) -> some View {
        scaleEffect(CGSize(width: x, height: y), anchor: anchor)
    }

    /// Rotates the view's rendered output around an anchor point.
    ///
    /// The transform is recorded on the view; transform rendering in
    /// backends is pending.
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View {
        RotationEffectView(content: self, angle: angle, anchor: anchor)
    }

    /// Offsets the view's rendered output.
    ///
    /// The offset is recorded on the view; offset rendering in backends is
    /// pending.
    public func offset(_ offset: CGSize) -> some View {
        OffsetView(content: self, offset: offset)
    }

    /// Offsets the view's rendered output.
    ///
    /// The offset is recorded on the view; offset rendering in backends is
    /// pending.
    public func offset(x: Double = 0, y: Double = 0) -> some View {
        self.offset(CGSize(width: x, height: y))
    }

    /// Applies a Gaussian blur to the view.
    ///
    /// The radius is recorded on the view; blur rendering in backends is
    /// pending.
    public func blur(radius: Double, opaque: Bool = false) -> some View {
        BlurView(content: self, radius: radius)
    }

    /// Sets the line spacing for text within the view.
    ///
    /// The value is carried through the environment; text layout applies it
    /// when line-spacing support lands.
    public func lineSpacing(_ lineSpacing: Double) -> some View {
        environment(\.lineSpacing, lineSpacing)
    }

    /// Sets an accessibility label for the view.
    ///
    /// The label is recorded on the view; accessibility support in backends
    /// is pending.
    public func accessibilityLabel(_ label: String) -> some View {
        AccessibilityLabelView(content: self, label: label)
    }

    /// Sets an accessibility label for the view.
    ///
    /// The label is recorded on the view; accessibility support in backends
    /// is pending.
    public func accessibilityLabel(_ label: Text) -> some View {
        AccessibilityLabelView(content: self, label: label.string)
    }

    /// Sets the bounce behavior for scroll views within this view.
    ///
    /// The preference is carried through the environment; scroll views read
    /// it when bounce-behavior support lands.
    public func scrollBounceBehavior(
        _ behavior: ScrollBounceBehavior,
        axes: Axis.Set = .vertical
    ) -> some View {
        environment(\.scrollBounceBehavior, behavior)
    }
}
