/// A view that needs custom dependency tracking when SwiftCrossUI refreshes
/// its observation state.
///
/// Most views can just rely on their `body`, but some wrappers read observable
/// state in other places such as `computeLayout` or modifier closures. Those
/// views can conform to this protocol so the graph observes the right
/// dependencies instead of only watching `body`.
@MainActor
protocol ObservationTrackingView: View {
    /// Reads the dependencies that should invalidate this view.
    func readObservationDependencies(in environment: EnvironmentValues)
}

extension ObservationTrackingView {
    func readObservationDependencies(in _: EnvironmentValues) {
        _ = body
    }
}
