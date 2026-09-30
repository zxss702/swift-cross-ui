/// A shape style that multiplies the resolved color's opacity, as in SwiftUI.
struct _OpacityShapeStyle<Base: ShapeStyle>: ShapeStyle {
    var base: Base
    var opacity: Double

    @MainActor
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        var resolved = base.resolve(in: environment)
        resolved.opacity *= Float(opacity)
        return resolved
    }
}

extension ShapeStyle {
    /// Multiplies the opacity of this style.
    public func opacity(_ opacity: Double) -> some ShapeStyle {
        _OpacityShapeStyle(base: self, opacity: opacity)
    }
}
