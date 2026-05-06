import Foundation

/// A two-column split view.
struct SplitView<Sidebar: View, Detail: View>: TypeSafeView, View {
    typealias Children = SplitViewChildren<EnvironmentModifier<Sidebar>, Detail>

    var body: TupleView2<EnvironmentModifier<Sidebar>, Detail>

    /// Creates a two-column split view.
    ///
    /// - Parameters:
    ///   - sidebar: The sidebar content.
    ///   - detail: The detail content.
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        body = TupleView2(
            EnvironmentModifier(sidebar()) { $0.with(\.listStyle, .sidebar) },
            detail()
        )
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        SplitViewChildren(
            wrapping: body.children(
                backend: backend,
                snapshots: snapshots,
                environment: environment
            ),
            backend: backend
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        return backend.createSplitView(
            leadingChild: children.leadingPaneContainer.into(),
            trailingChild: children.trailingPaneContainer.into()
        )
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let leadingWidth = Double(backend.sidebarWidth(ofSplitView: widget))

        let shouldMeasureMinimumWidths =
            !children.hasMeasuredMinimumWidths
            || (environment.allowLayoutCaching && proposedSize.width == 0)

        let leadingMinimumResult: ViewLayoutResult?
        let trailingMinimumResult: ViewLayoutResult?
        if shouldMeasureMinimumWidths {
            leadingMinimumResult = children.leadingChild.computeLayout(
                with: body.view0,
                proposedSize: ProposedViewSize(
                    0,
                    proposedSize.height
                ),
                environment: environment
            )

            trailingMinimumResult = children.trailingChild.computeLayout(
                with: body.view1,
                proposedSize: ProposedViewSize(
                    0,
                    proposedSize.height
                ),
                environment: environment
            )

            children.minimumLeadingWidth = leadingMinimumResult!.size.width
            children.minimumTrailingWidth = trailingMinimumResult!.size.width
            children.minimumLeadingHeight = leadingMinimumResult!.size.height
            children.minimumTrailingHeight = trailingMinimumResult!.size.height
            children.hasMeasuredMinimumWidths = true
        } else {
            leadingMinimumResult = nil
            trailingMinimumResult = nil
        }

        if proposedSize.width == 0,
            let leadingMinimumResult,
            let trailingMinimumResult
        {
            return ViewLayoutResult(
                size: ViewSize(
                    leadingMinimumResult.size.width + trailingMinimumResult.size.width,
                    max(leadingMinimumResult.size.height, trailingMinimumResult.size.height)
                ),
                childResults: [leadingMinimumResult, trailingMinimumResult]
            )
        }
        if proposedSize.width == 0 {
            return ViewLayoutResult(
                size: ViewSize(
                    children.minimumLeadingWidth + children.minimumTrailingWidth,
                    max(children.minimumLeadingHeight, children.minimumTrailingHeight)
                ),
                childResults: []
            )
        }

        // TODO: Figure out proper fixedSize behaviour (when width is unspecified)
        // Update pane children
        let leadingResult = children.leadingChild.computeLayout(
            with: body.view0,
            proposedSize: ProposedViewSize(
                proposedSize.width == nil ? nil : leadingWidth,
                proposedSize.height
            ),
            environment: environment
        )
        let trailingResult = children.trailingChild.computeLayout(
            with: body.view1,
            proposedSize: ProposedViewSize(
                proposedSize.width.map { max($0 - max(leadingWidth, leadingResult.size.width), 0) },
                proposedSize.height
            ),
            environment: environment
        )

        // Update split view size and sidebar width bounds
        let leadingContentSize = leadingResult.size
        let trailingContentSize = trailingResult.size
        var size = ViewSize(
            leadingContentSize.width + trailingContentSize.width,
            max(leadingContentSize.height, trailingContentSize.height)
        )

        if let proposedWidth = proposedSize.width {
            size.width = max(size.width, proposedWidth)
        }
        if let proposedHeight = proposedSize.height {
            size.height = max(size.height, proposedHeight)
        }

        return ViewLayoutResult(
            size: size,
            childResults: [leadingResult, trailingResult]
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setResizeHandler(ofSplitView: widget) {
            // The parameter to onResize is currently unused
            environment.onResize(.zero)
        }

<<<<<<< Updated upstream
        let leadingWidth = backend.sidebarWidth(ofSplitView: widget)
        let leadingResult = children.leadingChild.commit()
        let trailingResult = children.trailingChild.commit()
=======
        _ = children.leadingChild.commit()
        _ = children.trailingChild.commit()
>>>>>>> Stashed changes

        backend.setSize(of: widget, to: layout.size.vector)
        backend.setSidebarWidthBounds(
            ofSplitView: widget,
            minimum: LayoutSystem.roundSize(children.minimumLeadingWidth),
            maximum: LayoutSystem.roundSize(
                max(
                    children.minimumLeadingWidth,
                    layout.size.width - children.minimumTrailingWidth
                ))
        )

<<<<<<< Updated upstream
        // Center pane children
=======
        let leadingWidth = backend.sidebarWidth(ofSplitView: widget)
        let trailingWidth = max(layout.size.vector.x - leadingWidth, 0)
        backend.setSize(
            of: children.leadingPaneContainer.into(),
            to: SIMD2(leadingWidth, layout.size.vector.y)
        )
        backend.setSize(
            of: children.trailingPaneContainer.into(),
            to: SIMD2(trailingWidth, layout.size.vector.y)
        )

        // Native split views anchor pane content to the top-leading corner; the
        // pane containers provide the actual column size.
>>>>>>> Stashed changes
        backend.setPosition(
            ofChildAt: 0,
            in: children.leadingPaneContainer.into(),
            to: .zero
        )
        backend.setPosition(
            ofChildAt: 0,
            in: children.trailingPaneContainer.into(),
<<<<<<< Updated upstream
            to: SIMD2(
                layout.size.vector.x - leadingWidth - trailingResult.size.vector.x,
                layout.size.vector.y - trailingResult.size.vector.y
            ) / 2
=======
            to: .zero
>>>>>>> Stashed changes
        )
    }
}

class SplitViewChildren<Sidebar: View, Detail: View>: ViewGraphNodeChildren {
    var paneChildren: TupleView2<Sidebar, Detail>.Children
    var leadingPaneContainer: AnyWidget
    var trailingPaneContainer: AnyWidget
    var minimumLeadingWidth: Double
    var minimumTrailingWidth: Double
    var minimumLeadingHeight: Double
    var minimumTrailingHeight: Double
    var hasMeasuredMinimumWidths: Bool

    init<Backend: BaseAppBackend>(
        wrapping children: TupleView2<Sidebar, Detail>.Children,
        backend: Backend
    ) {
        self.paneChildren = children

        let leadingPaneContainer = backend.createContainer()
        backend.insert(
            paneChildren.child0.widget.into(),
            into: leadingPaneContainer,
            at: 0
        )
        let trailingPaneContainer = backend.createContainer()
        backend.insert(
            paneChildren.child1.widget.into(),
            into: trailingPaneContainer,
            at: 0
        )

        self.leadingPaneContainer = AnyWidget(leadingPaneContainer)
        self.trailingPaneContainer = AnyWidget(trailingPaneContainer)
        self.minimumLeadingWidth = 0
        self.minimumTrailingWidth = 0
        self.minimumLeadingHeight = 0
        self.minimumTrailingHeight = 0
        self.hasMeasuredMinimumWidths = false
    }

    var erasedNodes: [ErasedViewGraphNode] {
        paneChildren.erasedNodes
    }

    var widgets: [AnyWidget] {
        [
            leadingPaneContainer,
            trailingPaneContainer,
        ]
    }

    var leadingChild: AnyViewGraphNode<Sidebar> {
        paneChildren.child0
    }

    var trailingChild: AnyViewGraphNode<Detail> {
        paneChildren.child1
    }
}
