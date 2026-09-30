/// A style used to fill shapes and foregrounds.
///
/// Mirrors SwiftUI's `ShapeStyle`: conformers resolve to a concrete color
/// within a given environment. Gradients and materials are pending; color
/// based styles resolve today.
public protocol ShapeStyle: Sendable {
    /// Resolves this style to a concrete color in the given environment.
    @MainActor
    func resolve(in environment: EnvironmentValues) -> Color.Resolved
}

extension Color: ShapeStyle {}

/// Hierarchical semantic styles (`.primary`, `.secondary`, `.tertiary`,
/// `.quaternary`, `.quinary`), resolving to progressively fainter versions of
/// the environment's suggested foreground color.
public struct HierarchicalShapeStyle: ShapeStyle {
    enum Level: Int, Sendable {
        case primary, secondary, tertiary, quaternary, quinary
    }
    var level: Level

    public static let primary = HierarchicalShapeStyle(level: .primary)
    public static let secondary = HierarchicalShapeStyle(level: .secondary)
    public static let tertiary = HierarchicalShapeStyle(level: .tertiary)
    public static let quaternary = HierarchicalShapeStyle(level: .quaternary)
    public static let quinary = HierarchicalShapeStyle(level: .quinary)

    @MainActor
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let multiplier =
            switch level {
            case .primary: 1.0
            case .secondary: 0.6
            case .tertiary: 0.4
            case .quaternary: 0.25
            case .quinary: 0.15
            }
        return environment.suggestedForegroundColor
            .opacity(multiplier)
            .resolve(in: environment)
    }
}

/// A type-erased shape style.
public struct AnyShapeStyle: ShapeStyle {
    private let _resolve: @MainActor @Sendable (EnvironmentValues) -> Color.Resolved

    public init<S: ShapeStyle>(_ style: S) {
        _resolve = { environment in style.resolve(in: environment) }
    }

    @MainActor
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        _resolve(environment)
    }
}

extension ShapeStyle where Self == Color {
    /// A context-dependent red color suitable for foreground use.
    public static var red: Color { .red }
    /// A context-dependent green color suitable for foreground use.
    public static var green: Color { .green }
    /// A context-dependent blue color suitable for foreground use.
    public static var blue: Color { .blue }
    /// A context-dependent yellow color suitable for foreground use.
    public static var yellow: Color { .yellow }
    /// A context-dependent orange color suitable for foreground use.
    public static var orange: Color { .orange }
    /// A context-dependent purple color suitable for foreground use.
    public static var purple: Color { .purple }
    /// A context-dependent pink color suitable for foreground use.
    public static var pink: Color { .pink }
    /// A context-dependent mint color suitable for foreground use.
    public static var mint: Color { .mint }
    /// A context-dependent teal color suitable for foreground use.
    public static var teal: Color { .teal }
    /// A context-dependent gray color suitable for foreground use.
    public static var gray: Color { .gray }
    /// A context-dependent white color suitable for foreground use.
    public static var white: Color { .white }
    /// A context-dependent black color suitable for foreground use.
    public static var black: Color { .black }
    /// A context-dependent clear color suitable for foreground use.
    public static var clear: Color { .clear }
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    /// The hierarchical primary style.
    public static var primary: HierarchicalShapeStyle { .primary }
    /// The hierarchical secondary style.
    public static var secondary: HierarchicalShapeStyle { .secondary }
    /// The hierarchical tertiary style.
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
    /// The hierarchical quaternary style.
    public static var quaternary: HierarchicalShapeStyle { .quaternary }
    /// The hierarchical quinary style.
    public static var quinary: HierarchicalShapeStyle { .quinary }
}

/// The corner rounding style for shapes such as ``RoundedRectangle``.
public struct RoundedCornerStyle: Sendable {
    /// Rounds the corners to fit smoothly within the shape's bounds.
    public static let continuous = RoundedCornerStyle()
    /// Rounds the corners with quarter-circle arcs.
    public static let circular = RoundedCornerStyle()
}

extension View {
    /// Sets the foreground style of this view. Resolves styles to colors
    /// within the view's environment.
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        _ShapeStyleForegroundModifier(body: TupleView1(self), style: AnyShapeStyle(style))
    }
}

/// Resolves a ``ShapeStyle`` against the view's environment and forwards the
/// result via ``EnvironmentValues/suggestedForegroundColor``.
struct _ShapeStyleForegroundModifier<Content: View>: View {
    var body: TupleView1<Content>
    var style: AnyShapeStyle

    @MainActor
    private func resolving(_ environment: EnvironmentValues) -> EnvironmentValues {
        var environment = environment
        environment.foregroundColor = Color(style.resolve(in: environment))
        return environment
    }
}

extension _ShapeStyleForegroundModifier {
    @MainActor
    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> TupleView1<Content>.Children {
        body.children(
            backend: backend,
            snapshots: snapshots,
            environment: resolving(environment)
        )
    }

    @MainActor
    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: resolving(environment),
            backend: backend
        )
    }

    @MainActor
    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: resolving(environment),
            backend: backend
        )
    }
}

/// A translucent material style, mirroring SwiftUI's `Material`.
///
/// Backends without blur/material compositing resolve materials to a
/// translucent variant of the environment's suggested background color.
public struct Material: ShapeStyle {
    enum Level: Int, Sendable {
        case ultraThin, thin, regular, thick, ultraThick, bar
    }
    var level: Level

    public static let ultraThinMaterial = Material(level: .ultraThin)
    public static let thinMaterial = Material(level: .thin)
    public static let regularMaterial = Material(level: .regular)
    public static let thickMaterial = Material(level: .thick)
    public static let ultraThickMaterial = Material(level: .ultraThick)
    public static let barMaterial = Material(level: .bar)

    @MainActor
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let opacity: Float =
            switch level {
            case .ultraThin: 0.5
            case .thin: 0.65
            case .regular, .bar: 0.8
            case .thick: 0.9
            case .ultraThick: 0.97
            }
        return Color.adaptive(
            light: Color(red: 1, green: 1, blue: 1),
            dark: Color(red: 0.118, green: 0.118, blue: 0.118)
        )
        .opacity(Double(opacity))
        .resolve(in: environment)
    }
}

extension ShapeStyle where Self == Material {
    /// A material matching the content underneath.
    public static var regularMaterial: Material { .regularMaterial }
    /// A thin material.
    public static var thinMaterial: Material { .thinMaterial }
    /// An ultra-thin material.
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    /// A thick material.
    public static var thickMaterial: Material { .thickMaterial }
    /// An ultra-thick material.
    public static var ultraThickMaterial: Material { .ultraThickMaterial }
    /// A material matching the style of system bars.
    public static var barMaterial: Material { .barMaterial }
}
