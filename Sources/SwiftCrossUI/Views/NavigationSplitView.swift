/// A view that presents views in two or three columns.
public struct NavigationSplitView<Sidebar: View, MiddleBar: View, Detail: View>: View {
    /// The inner two-column split view. Its detail column either presents
    /// `detail` directly (two-column mode) or a nested split view containing
    /// `detail` (fixed trailing pane) and `content` (flexible middle column).
    var splitView: SplitView<Sidebar, EitherView<Detail, SplitView<Detail, MiddleBar>>>

    /// The column visibility binding supplied to `init(columnVisibility:...)`,
    /// if any.
    var columnVisibility: Binding<NavigationSplitViewVisibility>?

    public var body: some View { splitView }

    /// The sidebar content.
    public var sidebar: Sidebar
    /// The middle content.
    public var content: MiddleBar
    /// The detail content.
    public var detail: Detail

    /// Creates a three column split view.
    ///
    /// - Parameters:
    ///   - sidebar: The sidebar content.
    ///   - content: The middle content.
    ///   - detail: The detail content.
    public init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> MiddleBar,
        @ViewBuilder detail: () -> Detail
    ) {
        let sidebar = sidebar()
        let content = content()
        let detail = detail()
        self.init(sidebar: sidebar, content: content, detail: detail)
    }

    init(
        sidebar: Sidebar,
        content: MiddleBar,
        detail: Detail,
        columnVisibility: Binding<NavigationSplitViewVisibility>? = nil
    ) {
        self.sidebar = sidebar
        self.content = content
        self.detail = detail
        self.columnVisibility = columnVisibility
        let visibility = columnVisibility?.wrappedValue ?? .all
        let isSidebarVisible = visibility != .doubleColumn && visibility != .detailOnly
        splitView = SplitView(
            sidebar: { sidebar },
            detail: {
                if MiddleBar.self == EmptyView.self {
                    detail
                } else {
                    // The detail column becomes the inner split view's pane so
                    // that the middle column expands to fill the remaining
                    // space. The pane attaches to the trailing edge.
                    SplitView(
                        sidebar: { detail },
                        detail: { content },
                        paneOnTrailingEdge: true,
                        isPaneVisible: visibility != .detailOnly
                    )
                }
            },
            isPaneVisible: isSidebarVisible
        )
    }
}

extension NavigationSplitView where MiddleBar == EmptyView {
    /// Creates a two column split view.
    ///
    /// - Parameters:
    ///   - sidebar: The sidebar content.
    ///   - detail: The detail content.
    public init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.init(sidebar: sidebar(), content: EmptyView(), detail: detail())
    }
}

/// ``NavigationSplitView`` gets its own view graph node so that the inner
/// ``SplitView`` becomes a proper child node with its own backend widget.
/// Relying on `View`'s default forwarding would pass this node's container
/// widget to `SplitView.computeLayout`, which expects a real split view
/// widget.
extension NavigationSplitView: TypeSafeView {
    typealias Children = NavigationSplitViewChildren<Sidebar, MiddleBar, Detail>

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        NavigationSplitViewChildren(
            wrapping: splitView,
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.widget.into(), into: container, at: 0)
        backend.setPosition(ofChildAt: 0, in: container, to: .zero)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let result = children.node.computeLayout(
            with: splitView,
            proposedSize: proposedSize,
            environment: environment
        )
        return ViewLayoutResult(
            size: result.size,
            childResults: [result]
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

/// Holds the view graph node for a ``NavigationSplitView``'s inner split view.
class NavigationSplitViewChildren<Sidebar: View, MiddleBar: View, Detail: View>:
    ViewGraphNodeChildren
{
    typealias InnerSplitView = SplitView<
        Sidebar, EitherView<Detail, SplitView<Detail, MiddleBar>>
    >

    var node: AnyViewGraphNode<InnerSplitView>

    init<Backend: BaseAppBackend>(
        wrapping splitView: InnerSplitView,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        node = AnyViewGraphNode(
            for: splitView,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: node)]
    }

    var widgets: [AnyWidget] {
        [node.widget]
    }
}
