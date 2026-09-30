/// The visibility of the columns in a ``NavigationSplitView``.
public enum NavigationSplitViewVisibility: Hashable, Sendable {
    /// The platform chooses the visible columns.
    case automatic
    /// Only the detail column is shown.
    case detailOnly
    /// The content and detail columns are shown; the sidebar is hidden.
    case doubleColumn
    /// All columns are shown.
    case all
}

extension EnvironmentValues {
    /// The preferred width of the enclosing ``NavigationSplitView`` column,
    /// consumed by the split view's layout once column sizing lands.
    @Entry public var navigationSplitViewColumnWidth:
        (min: Double, ideal: Double, max: Double)?

    /// The background of the enclosing container presentation, applied by
    /// ``View/containerBackground(for:content:)``.
    @Entry public var containerBackgroundView: AnyView?
}

/// A region for which a view's container background applies.
public struct ContainerBackgroundPlacement: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case window
        case navigation
    }
    var kind: Kind

    /// The window region.
    public static let window = ContainerBackgroundPlacement(kind: .window)
    /// Navigation containers (split views, navigation stacks).
    public static let navigation = ContainerBackgroundPlacement(kind: .navigation)
}

extension View {
    /// Sets the preferred width of the enclosing ``NavigationSplitView``
    /// column.
    public func navigationSplitViewColumnWidth(
        min: Double? = nil,
        ideal: Double,
        max: Double? = nil
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(
                \.navigationSplitViewColumnWidth,
                (min: min ?? ideal, ideal: ideal, max: max ?? ideal)
            )
        }
    }

    /// Sets a fixed width for the enclosing ``NavigationSplitView`` column.
    public func navigationSplitViewColumnWidth(_ width: Double) -> some View {
        navigationSplitViewColumnWidth(min: width, ideal: width, max: width)
    }

    /// Sets the background view of the enclosing container.
    public func containerBackground<Content: View>(
        for placement: ContainerBackgroundPlacement,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let background = AnyView(content())
        return EnvironmentModifier(self) { environment in
            environment.with(\.containerBackgroundView, background)
        }
    }
}

extension NavigationSplitView {
    /// Creates a three column split view with column visibility control.
    ///
    /// Column visibility participates in layout once split-view collapse
    /// behavior lands; the binding is kept in sync when users reveal or hide
    /// columns.
    ///
    /// - Parameters:
    ///   - columnVisibility: A binding to the visible columns.
    ///   - sidebar: The sidebar content.
    ///   - content: The middle content.
    ///   - detail: The detail content.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> MiddleBar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.init(
            sidebar: sidebar(),
            content: content(),
            detail: detail(),
            columnVisibility: columnVisibility
        )
    }
}

extension NavigationSplitView where MiddleBar == EmptyView {
    /// Creates a two column split view with column visibility control.
    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.init(
            sidebar: sidebar(),
            content: EmptyView(),
            detail: detail(),
            columnVisibility: columnVisibility
        )
    }
}
