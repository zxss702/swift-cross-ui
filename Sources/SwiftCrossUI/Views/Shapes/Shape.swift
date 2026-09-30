import Foundation

/// A 2D shape that can be drawn as a view.
///
/// If no stroke color or fill color is specified, the default is no stroke and
/// a fill of the current foreground color.
public protocol Shape: View, Sendable, _RemoveGlobalActorIsolation, Animatable where Content == EmptyView {
    /// Draw the path for this shape.
    ///
    /// The bounds passed to a shape that is immediately drawn as a view will
    /// always have an origin of (0, 0). However, you may pass a different
    /// bounding box to subpaths. For example, this code draws a rectangle in
    /// the left half of the bounds and an ellipse in the right half:
    /// ```swift
    /// func path(in bounds: Path.Rect) -> Path {
    ///     Path()
    ///         .addSubpath(
    ///             Rectangle().path(
    ///                 in: Path.Rect(
    ///                     x: bounds.x,
    ///                     y: bounds.y,
    ///                     width: bounds.width / 2.0,
    ///                     height: bounds.height
    ///                 )
    ///             )
    ///         )
    ///         .addSubpath(
    ///             Ellipse().path(
    ///                 in: Path.Rect(
    ///                     x: bounds.center.x,
    ///                     y: bounds.y,
    ///                     width: bounds.width / 2.0,
    ///                     height: bounds.height
    ///                 )
    ///             )
    ///         )
    /// }
    /// ```
    ///
    /// - Parameter bounds: The bounds of this shape.
    func path(in bounds: Path.Rect) -> Path

    /// Draw the path for this shape, using SwiftUI's `CGRect` signature.
    ///
    /// Conforming types may implement either this overload or
    /// ``path(in:)-7kq2m``; each has a default implementation that forwards
    /// to the other. A type implementing neither will recurse at runtime.
    ///
    /// - Parameter bounds: The bounds of this shape.
    func path(in bounds: CGRect) -> Path

    /// Determine the ideal size of this shape given the proposed bounds.
    ///
    /// The default implementation accepts the proposal, replacing unspecified
    /// dimensions with 10.
    ///
    /// - Parameter proposal: The proposed bounds of this shape.
    /// - Returns: The shape's size for the given proposal.
    func size(fitting proposal: ProposedViewSize) -> ViewSize
}

extension Shape {
    public var body: EmptyView { return EmptyView() }

    /// The animatable data of the shape, empty by default as in SwiftUI.
    public var animatableData: EmptyAnimatableData {
        get { EmptyAnimatableData() }
        set {}
    }

    /// Forwards `CGRect`-based path requests to the ``Path/Rect`` overload.
    public func path(in bounds: CGRect) -> Path {
        path(in: Path.Rect(bounds))
    }

    /// Forwards ``Path/Rect``-based path requests to the `CGRect` overload.
    public func path(in bounds: Path.Rect) -> Path {
        path(in: CGRect(bounds))
    }

    public func size(fitting proposal: ProposedViewSize) -> ViewSize {
        proposal.replacingUnspecifiedDimensions(by: ViewSize(10, 10))
    }

    @MainActor
    public func children<Backend: BaseAppBackend>(
        backend _: Backend,
        snapshots _: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment _: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        ShapeStorage()
    }

    @MainActor
    @CastBackend<BackendFeatures.Paths>(returnsWidget: true)
    public func asWidget<Backend: BaseAppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createPathWidget()
        let storage = children as! ShapeStorage
        storage.backendPath = backend.createPath()
        storage.oldPath = nil
        return container
    }

    @MainActor
    public func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let size = size(fitting: proposedSize)
        return ViewLayoutResult.leafView(size: size)
    }

    @MainActor
    @CastBackend<BackendFeatures.Paths>(backendGenericName: "NewBackend")
    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let bounds = Path.Rect(
            x: 0.0,
            y: 0.0,
            width: layout.size.width,
            height: layout.size.height
        )
        let path = path(in: bounds)

        let storage = children as! ShapeStorage
        let pointsChanged = storage.oldPath?.actions != path.actions
        storage.oldPath = path

        guard let backendPath = storage.backendPath as? NewBackend.Path else {
            // The shape was flattened into a parent container (e.g. via a
            // pass-through modifier view) so `asWidget` never ran; skip
            // rendering rather than crashing on the missing backend path.
            backend.setSize(of: widget, to: layout.size.vector)
            return
        }
        backend.updatePath(
            backendPath,
            path,
            bounds: bounds,
            pointsChanged: pointsChanged,
            environment: environment
        )

        backend.setSize(of: widget, to: layout.size.vector)
        backend.renderPath(
            backendPath,
            container: widget,
            strokeColor: Color.clear.resolve(in: environment),
            fillColor: environment.suggestedForegroundColor.resolve(in: environment),
            overrideStrokeStyle: nil
        )
    }
}

final class ShapeStorage: ViewGraphNodeChildren {
    let widgets: [AnyWidget] = []
    let erasedNodes: [ErasedViewGraphNode] = []
    var backendPath: Any!
    var oldPath: Path?
}
