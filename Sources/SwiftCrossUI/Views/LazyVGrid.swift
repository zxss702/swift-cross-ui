/// The size and alignment of a ``LazyVGrid`` column or ``LazyHGrid`` row.
public struct GridItem: Sendable {
    /// The size specification of a grid item.
    public enum Size: Sendable {
        /// A fixed size.
        case fixed(Double)
        /// A flexible size within the given bounds.
        case flexible(minimum: Double = 10, maximum: Double = .infinity)
        /// Adaptive sizing: as many items of at least `minimum` width as fit.
        case adaptive(minimum: Double, maximum: Double = .infinity)
    }

    /// The item's size.
    public var size: Size
    /// The spacing between this item and the next.
    public var spacing: Double?
    /// The item's alignment within its cell.
    public var alignment: Alignment?

    /// Creates a grid item with the given size.
    public init(
        _ size: Size = .flexible(),
        spacing: Double? = nil,
        alignment: Alignment? = nil
    ) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }
}

/// A view that provides child views for grid introspection.
protocol _GridChildViewsIntrospectable {
    @MainActor func _introspectChildViews() -> [AnyView]
}

extension TupleView1: _GridChildViewsIntrospectable where View0: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0)]
    }
}
extension TupleView2: _GridChildViewsIntrospectable where View0: View, View1: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1)]
    }
}
extension TupleView3: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2)]
    }
}
extension TupleView4: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3)]
    }
}
extension TupleView5: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4)]
    }
}
extension TupleView6: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5)]
    }
}
extension TupleView7: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6)]
    }
}
extension TupleView8: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7)]
    }
}
extension TupleView9: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8)]
    }
}
extension TupleView10: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9)]
    }
}
extension TupleView11: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10)]
    }
}
extension TupleView12: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11)]
    }
}
extension TupleView13: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12)]
    }
}
extension TupleView14: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13)]
    }
}
extension TupleView15: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14)]
    }
}
extension TupleView16: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View, View15: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14), AnyView(self.view15)]
    }
}
extension TupleView17: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View, View15: View, View16: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14), AnyView(self.view15), AnyView(self.view16)]
    }
}
extension TupleView18: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View, View15: View, View16: View, View17: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14), AnyView(self.view15), AnyView(self.view16), AnyView(self.view17)]
    }
}
extension TupleView19: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View, View15: View, View16: View, View17: View, View18: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14), AnyView(self.view15), AnyView(self.view16), AnyView(self.view17), AnyView(self.view18)]
    }
}
extension TupleView20: _GridChildViewsIntrospectable where View0: View, View1: View, View2: View, View3: View, View4: View, View5: View, View6: View, View7: View, View8: View, View9: View, View10: View, View11: View, View12: View, View13: View, View14: View, View15: View, View16: View, View17: View, View18: View, View19: View {
    func _introspectChildViews() -> [AnyView] {
        [AnyView(self.view0), AnyView(self.view1), AnyView(self.view2), AnyView(self.view3), AnyView(self.view4), AnyView(self.view5), AnyView(self.view6), AnyView(self.view7), AnyView(self.view8), AnyView(self.view9), AnyView(self.view10), AnyView(self.view11), AnyView(self.view12), AnyView(self.view13), AnyView(self.view14), AnyView(self.view15), AnyView(self.view16), AnyView(self.view17), AnyView(self.view18), AnyView(self.view19)]
    }
}

extension ForEach: _GridChildViewsIntrospectable where Child: View {
    func _introspectChildViews() -> [AnyView] {
        elements.map { AnyView(child($0)) }
    }
}

/// A grid that arranges subviews in rows of the given columns.
///
/// Implemented on top of ``Grid``/``GridRow`` by introspecting the content's
/// child views and chunking them into rows. Children that cannot be
/// introspected occupy a single full-width row.
public struct LazyVGrid<Content: View>: View {
    private var columns: [GridItem]
    private var alignment: HorizontalAlignment
    private var spacing: Double?
    private var content: Content

    /// Creates a grid with the given columns.
    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body = EmptyView()

    /// Builds the grid content for the resolved columns. Kept separate from
    /// layout so the grid can size itself naturally along the vertical axis —
    /// a `GeometryReader`-based implementation would collapse to the
    /// reader's fallback height inside a `ScrollView` (where the height
    /// proposal is unspecified).
    private func innerView(
        resolvedColumns: [(width: Double, alignment: Alignment)],
        views: [AnyView]
    ) -> AnyView {
        let columnCount = max(resolvedColumns.count, 1)
        let rows = stride(from: 0, to: views.count, by: columnCount).map {
            Array(views[$0..<min($0 + columnCount, views.count)])
        }
        return AnyView(
            Grid(
                alignment: Alignment(horizontal: alignment, vertical: .center),
                horizontalSpacing: spacing,
                verticalSpacing: spacing
            ) {
                ForEach(Array(rows.enumerated()), id: \.offset) { row in
                    GridRow(alignment: .center) {
                        ForEach(Array(row.element.enumerated()), id: \.offset) { cell in
                            let column = resolvedColumns[
                                min(cell.offset, resolvedColumns.count - 1)
                            ]
                            cell.element
                                .frame(width: column.width, alignment: column.alignment)
                        }
                    }
                }
            }
        )
    }

    /// Resolves the declared `GridItem`s into concrete columns for the given
    /// width, honouring `.fixed`, `.adaptive` and `.flexible` semantics.
    private func resolveColumns(
        availableWidth: Double
    ) -> [(width: Double, alignment: Alignment)] {
        let items = columns.isEmpty ? [GridItem(.flexible())] : columns
        let defaultSpacing = spacing ?? 8

        func trailingSpacing(of index: Int) -> Double {
            items[index].spacing ?? defaultSpacing
        }

        // Deduct the gaps between declared items.
        var remaining = availableWidth
        for index in items.indices.dropLast() {
            remaining -= trailingSpacing(of: index)
        }

        var groups: [[(width: Double, alignment: Alignment)]] = []
        var flexibles: [(index: Int, minimum: Double, maximum: Double)] = []

        for (index, item) in items.enumerated() {
            let alignment = item.alignment ?? .center
            switch item.size {
            case .fixed(let width):
                groups.append([(width, alignment)])
                remaining -= width
            case .flexible(let minimum, let maximum):
                groups.append([])
                flexibles.append((index, minimum, maximum))
            case .adaptive(let minimum, let maximum):
                // An adaptive item expands into as many columns as fit in
                // its share of the remaining width.
                let pending = items[index...].count
                let share = remaining / Double(pending)
                let gap = trailingSpacing(of: index)
                let count = max(1, Int((share + gap) / (minimum + gap)))
                let width = min(maximum, max(minimum, share / Double(count)))
                groups.append(
                    Array(
                        repeating: (width, alignment),
                        count: count
                    )
                )
                remaining -= Double(count) * width + Double(count - 1) * gap
            }
        }

        // Leftover space is shared between flexible items.
        let flexibleShare = remaining / Double(max(flexibles.count, 1))
        for (index, minimum, maximum) in flexibles {
            let width = min(max(flexibleShare, minimum), maximum)
            groups[index] = [(width, items[index].alignment ?? .center)]
        }

        return groups.flatMap { $0 }
    }
}

/// A grid that arranges subviews in columns of the given rows.
///
/// Implemented on top of ``Grid`` by introspecting the content's child views
/// and chunking them into single-column rows.
public struct LazyHGrid<Content: View>: View {
    private var rows: [GridItem]
    private var alignment: VerticalAlignment
    private var spacing: Double?
    private var content: Content

    /// Creates a grid with the given rows.
    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body = EmptyView()

    /// Builds the grid content for the resolved rows; see ``LazyVGrid``'s
    /// `innerView` for why this isn't a `GeometryReader`-based `body`.
    private func innerView(
        resolvedRows: [(height: Double, alignment: Alignment)],
        views: [AnyView]
    ) -> AnyView {
        let rowCount = max(resolvedRows.count, 1)
        let columns = stride(from: 0, to: views.count, by: rowCount).map {
            Array(views[$0..<min($0 + rowCount, views.count)])
        }
        return AnyView(
            HStack(alignment: alignment, spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { column in
                    VStack(spacing: spacing) {
                        ForEach(Array(column.element.enumerated()), id: \.offset) { cell in
                            let row = resolvedRows[
                                min(cell.offset, resolvedRows.count - 1)
                            ]
                            cell.element
                                .frame(height: row.height, alignment: row.alignment)
                        }
                    }
                }
            }
        )
    }

    /// Resolves the declared `GridItem`s into concrete rows for the given
    /// height, honouring `.fixed`, `.adaptive` and `.flexible` semantics.
    private func resolveRows(
        availableHeight: Double
    ) -> [(height: Double, alignment: Alignment)] {
        let items = rows.isEmpty ? [GridItem(.flexible())] : rows
        let defaultSpacing = spacing ?? 8

        var remaining = availableHeight
        for index in items.indices.dropLast() {
            remaining -= items[index].spacing ?? defaultSpacing
        }

        var groups: [[(height: Double, alignment: Alignment)]] = []
        var flexibles: [(index: Int, minimum: Double, maximum: Double)] = []

        for (index, item) in items.enumerated() {
            let alignment = item.alignment ?? .center
            switch item.size {
            case .fixed(let height):
                groups.append([(height, alignment)])
                remaining -= height
            case .flexible(let minimum, let maximum):
                groups.append([])
                flexibles.append((index, minimum, maximum))
            case .adaptive(let minimum, let maximum):
                let pending = items[index...].count
                let share = remaining / Double(pending)
                let gap = item.spacing ?? defaultSpacing
                let count = max(1, Int((share + gap) / (minimum + gap)))
                let height = min(maximum, max(minimum, share / Double(count)))
                groups.append(
                    Array(
                        repeating: (height, alignment),
                        count: count
                    )
                )
                remaining -= Double(count) * height + Double(count - 1) * gap
            }
        }

        let flexibleShare = remaining / Double(max(flexibles.count, 1))
        for (index, minimum, maximum) in flexibles {
            let height = min(max(flexibleShare, minimum), maximum)
            groups[index] = [(height, items[index].alignment ?? .center)]
        }

        return groups.flatMap { $0 }
    }
}

/// Shared node storage for a lazily-generated grid child view.
class LazyGridChildren: ViewGraphNodeChildren {
    var node: AnyViewGraphNode<AnyView>?

    var widgets: [AnyWidget] {
        [node?.widget].compactMap { $0 }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node.map(ErasedViewGraphNode.init(wrapping:))].compactMap { $0 }
    }
}

extension LazyVGrid: TypeSafeView {
    typealias Children = LazyGridChildren

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children()
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let views = (content as? _GridChildViewsIntrospectable)?._introspectChildViews()
            ?? [AnyView(content)]
        // Resolve columns against the proposed width only; the grid's height
        // is whatever its rows need (this is what makes it scrollable).
        let resolvedColumns = resolveColumns(availableWidth: proposedSize.width ?? 200)
        let view = innerView(resolvedColumns: resolvedColumns, views: views)

        let node: AnyViewGraphNode<AnyView>
        if let existing = children.node {
            node = existing
        } else {
            node = AnyViewGraphNode(for: view, backend: backend, environment: environment)
            children.node = node
            backend.insert(node.widget.into(), into: widget, at: 0)
        }

        let contentResult = node.computeLayout(
            with: view,
            proposedSize: proposedSize,
            environment: environment
        )

        return ViewLayoutResult(
            size: contentResult.size,
            childResults: [contentResult]
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node?.commit()
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

extension LazyHGrid: TypeSafeView {
    typealias Children = LazyGridChildren

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children()
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let views = (content as? _GridChildViewsIntrospectable)?._introspectChildViews()
            ?? [AnyView(content)]
        // Resolve rows against the proposed height only; the grid's width
        // is whatever its columns need.
        let resolvedRows = resolveRows(availableHeight: proposedSize.height ?? 200)
        let view = innerView(resolvedRows: resolvedRows, views: views)

        let node: AnyViewGraphNode<AnyView>
        if let existing = children.node {
            node = existing
        } else {
            node = AnyViewGraphNode(for: view, backend: backend, environment: environment)
            children.node = node
            backend.insert(node.widget.into(), into: widget, at: 0)
        }

        let contentResult = node.computeLayout(
            with: view,
            proposedSize: proposedSize,
            environment: environment
        )

        return ViewLayoutResult(
            size: contentResult.size,
            childResults: [contentResult]
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node?.commit()
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        backend.setSize(of: widget, to: layout.size.vector)
    }
}
