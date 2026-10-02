#if canImport(Observation)
    import Observation
#else
    import ObservationPolyfill
#endif

/// The visible region of a scroll view, published to its descendants via the
/// environment so that lazy containers (such as ``LazyVStack``) can
/// materialize only the visible slice of their content.
///
/// Reading a property of this object from within a view's `computeLayout`
/// registers a dependency through the regular observation machinery, so
/// scrolling causes lazy containers to re-evaluate which elements to
/// materialize without dirtying the scroll view's other descendants.
@Observable
final class ScrollViewport: @unchecked Sendable {
    /// The current scroll offset along the main (vertical) axis, in points.
    var verticalOffset = 0.0
    /// The extent of the viewport along the main axis, in points. Zero until
    /// the scroll view has committed a layout at least once.
    var viewportHeight = 0.0

    /// Updates the viewport, avoiding invalidation when nothing changed.
    @MainActor
    func update(verticalOffset: Double, viewportHeight: Double) {
        if self.verticalOffset != verticalOffset {
            self.verticalOffset = verticalOffset
        }
        if self.viewportHeight != viewportHeight {
            self.viewportHeight = viewportHeight
        }
    }
}
