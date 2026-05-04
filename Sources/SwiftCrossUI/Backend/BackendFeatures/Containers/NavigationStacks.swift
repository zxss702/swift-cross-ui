extension BackendFeatures {
    /// Backend methods for stack-style navigation containers.
    ///
    /// Backends can adopt this protocol to present ``NavigationStack`` using a
    /// platform navigation controller while SwiftCrossUI continues to manage the
    /// navigation path and destination view graph.
    @MainActor
    public protocol NavigationStacks: Core {
        /// Creates an empty navigation stack widget.
        func createNavigationStack() -> Widget

        /// Updates the pages currently represented by a navigation stack.
        ///
        /// - Parameters:
        ///   - navigationStack: The navigation stack widget.
        ///   - pages: The current root and destination pages, in path order.
        ///   - environment: The current environment.
        ///   - onPopToPage: Called when the user navigates back using native UI.
        ///     The page index includes the root page at index `0`.
        func setNavigationStackPages(
            of navigationStack: Widget,
            to pages: [NavigationStackPage<Widget>],
            environment: EnvironmentValues,
            onPopToPage: @escaping @MainActor (_ pageIndex: Int) -> Void
        )
    }
}

/// A page shown by a backend-native navigation stack.
@MainActor
public struct NavigationStackPage<Widget> {
    public var widget: Widget
    public var navigationTitle: String?
    public var toolbar: ResolvedToolbar

    public init(
        widget: Widget,
        navigationTitle: String?,
        toolbar: ResolvedToolbar
    ) {
        self.widget = widget
        self.navigationTitle = navigationTitle
        self.toolbar = toolbar
    }
}
