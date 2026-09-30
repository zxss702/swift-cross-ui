import Foundation

extension StrokeStyle {
    /// Creates a stroke style with SwiftUI-compatible parameter labels.
    public init(
        lineWidth: Double,
        lineCap: StrokeCap = .butt,
        lineJoin: StrokeJoin = .miter(limit: 10.0)
    ) {
        self.init(width: lineWidth, cap: lineCap, join: lineJoin)
    }
}

extension Path.Rect {
    /// Creates a ``Path/Rect`` from a `CGRect`.
    public init(_ rect: CGRect) {
        self.init(
            origin: SIMD2(x: rect.origin.x, y: rect.origin.y),
            size: SIMD2(x: rect.size.width, y: rect.size.height)
        )
    }
}

extension CGRect {
    /// Creates a `CGRect` from a ``Path/Rect``.
    public init(_ rect: Path.Rect) {
        self.init(
            x: CGFloat(rect.x),
            y: CGFloat(rect.y),
            width: CGFloat(rect.width),
            height: CGFloat(rect.height)
        )
    }
}

extension Path {
    /// Creates a path by mutating it in a callback, as in SwiftUI's
    /// `Path.init(_:)`.
    public init(_ build: (inout Path) -> Void) {
        self.init()
        build(&self)
    }

    /// Creates a path from a rectangle.
    public init(_ rect: CGRect) {
        self.init()
        self = addRectangle(
            Rect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        )
    }

    /// Creates a path containing an ellipse inscribed in the given rectangle,
    /// approximated by four cubic Bézier curves (κ ≈ 0.5523).
    public init(ellipseIn rect: CGRect) {
        self.init()
        let kappa = 0.552_284_749_830_8
        let rx = rect.width / 2
        let ry = rect.height / 2
        let cx = rect.midX
        let cy = rect.midY
        let ox = rx * kappa
        let oy = ry * kappa
        self = self
            .move(to: SIMD2(x: cx + rx, y: cy))
            .addCubicCurve(
                control1: SIMD2(x: cx + rx, y: cy + oy),
                control2: SIMD2(x: cx + ox, y: cy + ry),
                to: SIMD2(x: cx, y: cy + ry)
            )
            .addCubicCurve(
                control1: SIMD2(x: cx - ox, y: cy + ry),
                control2: SIMD2(x: cx - rx, y: cy + oy),
                to: SIMD2(x: cx - rx, y: cy)
            )
            .addCubicCurve(
                control1: SIMD2(x: cx - rx, y: cy - oy),
                control2: SIMD2(x: cx - ox, y: cy - ry),
                to: SIMD2(x: cx, y: cy - ry)
            )
            .addCubicCurve(
                control1: SIMD2(x: cx + ox, y: cy - ry),
                control2: SIMD2(x: cx + rx, y: cy - oy),
                to: SIMD2(x: cx + rx, y: cy)
            )
    }

    /// Creates a path containing a rounded rectangle.
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init()
        self = addSubpath(
            RoundedRectangle(cornerRadius: Double(cornerRadius)).path(
                in: Rect(
                    x: rect.origin.x,
                    y: rect.origin.y,
                    width: rect.size.width,
                    height: rect.size.height
                )
            )
        )
    }

    /// Moves the path's current point to the given point (mutating variant
    /// matching SwiftUI's `Path` API).
    public mutating func move(to point: CGPoint) {
        self = move(to: SIMD2(x: point.x, y: point.y))
    }

    /// Adds a line segment to the given point.
    public mutating func addLine(to point: CGPoint) {
        self = addLine(to: SIMD2(x: point.x, y: point.y))
    }

    /// Adds a cubic Bézier curve to the given point.
    public mutating func addCurve(
        to endPoint: CGPoint,
        control1: CGPoint,
        control2: CGPoint
    ) {
        self = addCubicCurve(
            control1: SIMD2(x: control1.x, y: control1.y),
            control2: SIMD2(x: control2.x, y: control2.y),
            to: SIMD2(x: endPoint.x, y: endPoint.y)
        )
    }

    /// Adds a quadratic Bézier curve to the given point.
    public mutating func addQuadCurve(to endPoint: CGPoint, control: CGPoint) {
        self = addQuadCurve(
            control: SIMD2(x: control.x, y: control.y),
            to: SIMD2(x: endPoint.x, y: endPoint.y)
        )
    }

    /// Closes the current subpath with a straight line back to its start.
    public mutating func closeSubpath() {
        for action in actions.reversed() {
            if case .moveTo(let start) = action {
                self = addLine(to: start)
                return
            }
        }
    }
}
