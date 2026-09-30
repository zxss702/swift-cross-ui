/// A shape that has style information attached to it, including color and
/// stroke style.
public protocol StyledShape: Shape {
    /// The shape's stroke color.
    var strokeColor: Color? { get }
    /// The shape's fill color.
    var fillColor: Color? { get }
    /// The shape's stroke style.
    var strokeStyle: StrokeStyle? { get }
    /// The shape's fill style, resolved against the environment at render
    /// time. Takes precedence over ``fillColor`` when present.
    var fillStyle: AnyShapeStyle? { get }
    /// The shape's stroke style as an environment-resolved style. Takes
    /// precedence over ``strokeColor`` when present.
    var strokeShapeStyle: AnyShapeStyle? { get }
}

extension StyledShape {
    public var fillStyle: AnyShapeStyle? { nil }
    public var strokeShapeStyle: AnyShapeStyle? { nil }
}

struct StyledShapeImpl<Base: Shape>: Sendable {
    var base: Base
    var strokeColor: Color?
    var fillColor: Color?
    var strokeStyle: StrokeStyle?
    var fillStyle: AnyShapeStyle?
    var strokeShapeStyle: AnyShapeStyle?

    init(
        base: Base,
        strokeColor: Color? = nil,
        fillColor: Color? = nil,
        strokeStyle: StrokeStyle? = nil,
        fillStyle: AnyShapeStyle? = nil,
        strokeShapeStyle: AnyShapeStyle? = nil
    ) {
        self.base = base
        self.fillStyle = fillStyle
        self.strokeShapeStyle = strokeShapeStyle

        if let styledBase = base as? any StyledShape {
            self.strokeColor = strokeColor ?? styledBase.strokeColor
            self.fillColor = fillColor ?? styledBase.fillColor
            self.strokeStyle = strokeStyle ?? styledBase.strokeStyle
        } else {
            self.strokeColor = strokeColor
            self.fillColor = fillColor
            self.strokeStyle = strokeStyle
        }
    }
}

extension StyledShapeImpl: StyledShape {
    func path(in bounds: Path.Rect) -> Path {
        return base.path(in: bounds)
    }

    func size(fitting proposal: ProposedViewSize) -> ViewSize {
        return base.size(fitting: proposal)
    }
}

extension Shape {
    public func fill(_ color: Color) -> some StyledShape {
        StyledShapeImpl(base: self, fillColor: color)
    }

    /// Fills this shape with the given style, resolving it in the view's
    /// environment at render time.
    public func fill<S: ShapeStyle>(_ style: S) -> some StyledShape {
        StyledShapeImpl(base: self, fillStyle: AnyShapeStyle(style))
    }

    public func stroke(_ color: Color, style: StrokeStyle? = nil) -> some StyledShape {
        StyledShapeImpl(base: self, strokeColor: color, strokeStyle: style)
    }

    /// Strokes this shape with the given color and line width, as in
    /// SwiftUI's `stroke(_:lineWidth:antialiased:)` overload.
    public func stroke(
        _ color: Color,
        lineWidth: Double = 1,
        antialiased: Bool = true
    ) -> some StyledShape {
        StyledShapeImpl(base: self, strokeColor: color, strokeStyle: StrokeStyle(lineWidth: lineWidth))
    }

    /// Strokes this shape with the given style and line width, as in
    /// SwiftUI's `stroke(_:lineWidth:antialiased:)` overload.
    public func stroke<S: ShapeStyle>(
        _ style: S,
        lineWidth: Double = 1,
        antialiased: Bool = true
    ) -> some StyledShape {
        StyledShapeImpl(
            base: self,
            strokeStyle: StrokeStyle(lineWidth: lineWidth),
            strokeShapeStyle: AnyShapeStyle(style)
        )
    }

    /// Strokes this shape's border with the given style.
    ///
    /// Currently rendered identically to ``stroke(_:style:)-7x8d4``; the
    /// border-inset distinction requires backend path-inset support.
    public func strokeBorder<S: ShapeStyle>(
        _ style: S,
        lineWidth: Double = 1,
        antialiased: Bool = true
    ) -> some StyledShape {
        StyledShapeImpl(
            base: self,
            strokeStyle: StrokeStyle(lineWidth: lineWidth),
            strokeShapeStyle: AnyShapeStyle(style)
        )
    }

    /// Strokes this shape's border with the given color.
    public func strokeBorder(
        _ color: Color,
        style: StrokeStyle,
        antialiased: Bool = true
    ) -> some StyledShape {
        StyledShapeImpl(base: self, strokeColor: color, strokeStyle: style)
    }
}

extension StyledShape {
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
            strokeColor: strokeShapeStyle?.resolve(in: environment)
                ?? (strokeColor ?? .clear).resolve(in: environment),
            fillColor: fillStyle?.resolve(in: environment)
                ?? (fillColor ?? .clear).resolve(in: environment),
            overrideStrokeStyle: strokeStyle
        )
    }
}
