import Foundation

/// A context passed to a ``Canvas`` renderer closure. Drawing operations are
/// recorded and replayed as a stack of shapes and resolved subviews.
public struct GraphicsContext {
    /// How a path is shaded when filling or stroking.
    public struct Shading: Sendable {
        enum Kind: Sendable {
            case color(Color)
            case style(AnyShapeStyle)
        }
        var kind: Kind

        /// Shades with a solid color.
        public static func color(_ color: Color) -> Shading {
            Shading(kind: .color(color))
        }

        /// Shades with a shape style (resolved against the environment).
        public static func style<S: ShapeStyle>(_ style: S) -> Shading {
            Shading(kind: .style(AnyShapeStyle(style)))
        }
    }

    /// A style controlling how a path is filled.
    public struct FillStyle: Sendable {
        /// Whether to use the even-odd rule.
        public var eoFill: Bool
        /// Whether the fill is antialiased.
        public var antialiased: Bool

        public init(eoFill: Bool = false, antialiased: Bool = true) {
            self.eoFill = eoFill
            self.antialiased = antialiased
        }
    }

    /// A view resolved for drawing within the canvas.
    public struct ResolvedView {
        var view: AnyView
    }

    enum Operation {
        case fill(Path, Shading, FillStyle)
        case stroke(Path, Shading, StrokeStyle)
        case draw(ResolvedView, CGPoint, UnitPoint)
    }

    var operations: [Operation] = []

    public init() {}

    /// Resolves a view so that it can be drawn via ``draw(_:at:anchor:)``.
    public func resolve<V: View>(_ view: V) -> ResolvedView {
        ResolvedView(view: AnyView(view))
    }

    /// Fills a path.
    public mutating func fill(
        _ path: Path,
        with shading: Shading,
        style: FillStyle = FillStyle()
    ) {
        operations.append(.fill(path, shading, style))
    }

    /// Strokes a path.
    public mutating func stroke(
        _ path: Path,
        with shading: Shading,
        style: StrokeStyle
    ) {
        operations.append(.stroke(path, shading, style))
    }

    /// Strokes a path with a line width.
    public mutating func stroke(
        _ path: Path,
        with shading: Shading,
        lineWidth: Double = 1
    ) {
        operations.append(.stroke(path, shading, StrokeStyle(width: lineWidth)))
    }

    /// Draws a resolved view anchored at the given point.
    public mutating func draw(
        _ resolved: ResolvedView,
        at point: CGPoint,
        anchor: UnitPoint = .center
    ) {
        operations.append(.draw(resolved, point, anchor))
    }
}

/// A view that renders imperative drawing instructions, mirroring SwiftUI's
/// `Canvas`. The renderer closure records operations into a
/// ``GraphicsContext``; the canvas replays them as an ordered stack of shapes
/// and resolved subviews.
public struct Canvas: View {
    var renderer: (inout GraphicsContext, CGSize) -> Void

    public init(renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {
        self.renderer = renderer
    }

    /// Wraps a recorded ``Path`` as a shape so it can be filled or stroked
    /// using the existing shape styling machinery.
    struct FixedPath: Shape {
        var path: Path

        func path(in bounds: Path.Rect) -> Path {
            path
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            CanvasContent(size: proxy.size, renderer: renderer)
        }
    }

    private struct CanvasContent: View {
        var size: CGSize
        var renderer: (inout GraphicsContext, CGSize) -> Void

        @Environment(\.self) private var environment

        var body: some View {
            var context = GraphicsContext()
            renderer(&context, size)
            return ZStack(alignment: .topLeading) {
                ForEach(Array(context.operations.enumerated()), id: \.offset) { pair in
                    render(pair.element, canvasSize: size)
                }
            }
        }

        @ViewBuilder
        private func render(
            _ operation: GraphicsContext.Operation,
            canvasSize: CGSize
        ) -> some View {
            switch operation {
            case .fill(let path, let shading, let style):
                FixedPath(path: path.fillRule(style.eoFill ? .evenOdd : .winding))
                    .fill(shading.resolve(in: environment))

            case .stroke(let path, let shading, let style):
                FixedPath(path: path)
                    .stroke(shading.resolve(in: environment), style: style)

            case .draw(let resolved, let point, let anchor):
                Self.positioned(resolved.view, at: point, anchor: anchor, canvasSize: canvasSize)
            }
        }

        /// Positions a resolved view so that the given anchor point of the
        /// view lands on `point` within the canvas. Supports the standard
        /// anchor set ({0, 0.5, 1} on each axis); other anchors are snapped to
        /// the nearest representable position.
        private static func positioned(
            _ view: AnyView,
            at point: CGPoint,
            anchor: UnitPoint,
            canvasSize: CGSize
        ) -> some View {
            let (containerWidth, hAlignment, offsetX) = horizontalPlacement(
                anchor.x,
                point.x,
                canvasSize.width
            )
            let (containerHeight, vAlignment, offsetY) = verticalPlacement(
                anchor.y,
                point.y,
                canvasSize.height
            )
            return view
                .frame(
                    width: containerWidth,
                    height: containerHeight,
                    alignment: Alignment(horizontal: hAlignment, vertical: vAlignment)
                )
                .offset(x: offsetX, y: offsetY)
        }

        private static func horizontalPlacement(
            _ anchor: Double,
            _ point: Double,
            _ canvasWidth: Double
        ) -> (Double, HorizontalAlignment, Double) {
            if anchor <= 0 {
                // The view's leading edge sits at `point`: full-width
                // container, leading alignment, then shift right by `point`.
                return (canvasWidth, .leading, point)
            } else if anchor < 0.75 {
                // The view's center lands at `point`.
                return (point / 0.5, .center, 0)
            } else {
                // The view's trailing edge lands at `point`.
                return (point, .trailing, 0)
            }
        }

        private static func verticalPlacement(
            _ anchor: Double,
            _ point: Double,
            _ canvasHeight: Double
        ) -> (Double, VerticalAlignment, Double) {
            if anchor <= 0 {
                return (canvasHeight, .top, point)
            } else if anchor < 0.75 {
                return (point / 0.5, .center, 0)
            } else {
                return (point, .bottom, 0)
            }
        }
    }
}

extension GraphicsContext.Shading {
    /// Resolves the shading to a solid color in the given environment.
    @MainActor
    func resolve(in environment: EnvironmentValues) -> Color {
        switch kind {
        case .color(let color):
            return color
        case .style(let style):
            return Color(style.resolve(in: environment))
        }
    }
}
