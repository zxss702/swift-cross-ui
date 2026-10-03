import Foundation

/// A view that displays a variable amount of children.
public struct ForEach<Items: Collection, ID: Hashable, Child> {
    /// A variable-length collection of elements to display.
    var elements: Items
    /// A method to display the elements as views.
    var child: (Items.Element) -> Child
    /// The path to the property used as Identifier
    var idKeyPath: KeyPath<Items.Element, ID>?
}

extension ForEach: TypeSafeView, View where Child: View {
    typealias Children = ForEachViewChildren<Items, ID, Child>

    /// Creates a view that creates child views on demand based on a collection
    /// of data.
    ///
    /// One instance of `child` will be rendered for every element in
    /// `elements`.
    ///
    /// - Parameters:
    ///   - elements: The collection to build an array of views from.
    ///   - keyPath: A key path to the element type's ID.
    ///   - child: A view builder that returns an appropriate view for
    ///     each element of `elements`.
    public init(
        _ elements: Items,
        id keyPath: KeyPath<Items.Element, ID>,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = keyPath
    }

    public var body: EmptyView {
        return EmptyView()
    }

    public var _asMenuItems: [MenuItem] {
        elements.map(child).flatMap(\._asMenuItems)
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        return Children(
            from: self,
            backend: backend,
            idKeyPath: idKeyPath,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        return backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        func insertChild(_ child: Backend.Widget, atIndex index: Int) {
            children.queuedChanges.append(.insertChild(AnyWidget(child), index))
        }

        func removeChild(atIndex index: Int) {
            children.queuedChanges.append(.removeChild(index))
        }

        func swap(childAt firstIndex: Int, withChildAt secondIndex: Int) {
            children.queuedChanges.append(.swapChildren(firstIndex, secondIndex))
        }

        // Use the previous update Method when no keyPath is set on a
        // [Hashable] Collection to optionally keep the old behaviour.
        guard let idKeyPath else {
            return deprecatedUpdate(
                widget,
                children: children,
                proposedSize: proposedSize,
                environment: environment,
                backend: backend
            )
        }

        if environment.lazyStackEnabled,
            let viewport = environment.scrollViewport,
            environment.layoutOrientation == .vertical
        {
            return computeWindowedLayout(
                widget,
                children: children,
                viewport: viewport,
                idKeyPath: idKeyPath,
                proposedSize: proposedSize,
                environment: environment,
                backend: backend
            )
        }

        if children.isWindowed {
            // Leaving windowed mode: drop the materialized widgets; the eager
            // diff below repopulates the container from scratch.
            for index in (0..<children.containerIDs.count).reversed() {
                children.queuedChanges.append(.removeChild(index))
            }
            children.containerIDs = []
            children.windowedNodes = []
            children.nodesByID = [:]
            children.windowedElements = []
            children.measuredHeights = [:]
            children.measuredViews = [:]
            children.measuredWidths = [:]
            children.isWindowed = false
        }

        var oldIdentifiers = children.identifiers
        let newIdentifiers = elements.map { $0[keyPath: idKeyPath] }

        // If the identifiers of our elements have changed, then we must rearrange
        // our nodes and widgets so that child view states remain with their
        // corresponding identifiers.
        if oldIdentifiers != newIdentifiers {
            var oldIdentifierMap = children.identifierMap
            var oldNodes = children.nodes
            var seenIdentifiers = Set<ID>()
            var oldNodesReused = 0
            children.nodes = []
            children.identifierMap = [:]
            children.identifiers = []
            children.layoutableChildren = []

            var offset = 0
            var duplicateCount = 0
            for (index, element) in elements.enumerated() {
                let identifier = newIdentifiers[index]
                let childContent = child(element)
                let node: AnyViewGraphNode<Child>

                if !seenIdentifiers.insert(identifier).inserted {
                    // We cannot keep view state attached to the correct ForEach element
                    // when there are duplicate identifiers. Any elements with unique
                    // identifiers are guaranteed to keep functioning correctly. Elements
                    // with non-unique identifiers will get their corresponding view graph
                    // nodes recreated each time the identifiers of our elements change,
                    // unless they are the first element with the shared identifier, in which
                    // case they will inherit the view graph node of the previous first element
                    // with that same identifier.
                    logger.warning(
                        "duplicate identifier in ForEach; view state may not act as you would expect",
                        metadata: ["identifier": "\(identifier)"]
                    )
                    duplicateCount += 1
                }

                if let oldIndex = oldIdentifierMap.removeValue(forKey: identifier) {
                    // If the identifier already has a corresponding node, reuse it.
                    node = oldNodes[oldIndex]
                    oldNodesReused += 1

                    // If the node's corresponding widget isn't already at the correct
                    // position (accounting for insertions), then swap it with the widget
                    // at the target position and update our accounting accordinly.
                    if index != offset + oldIndex {
                        // When talking about current widget indices, we add `offset` to oldIndex.
                        // When talking about old element indices, we subtract `offset` from index.
                        swap(childAt: offset + oldIndex, withChildAt: index)
                        oldNodes.swapAt(oldIndex, index - offset)
                        oldIdentifierMap[oldIdentifiers[index - offset]] = oldIndex
                        oldIdentifiers.swapAt(oldIndex, index - offset)
                    }
                } else {
                    // If the identifier is new, create a node for it and insert its
                    // widget at the correct position.
                    node = AnyViewGraphNode(
                        for: childContent,
                        backend: backend,
                        environment: environment
                    )
                    insertChild(node.widget.into(), atIndex: index)

                    // `offset` tracks how many elements have been inserted, which we
                    // use to adjust old indices. All nodes before the one we just
                    // inserted are already at their final position, so we never have
                    // to adjust old indices that point to before our latest insertion, otherwise
                    // such a simple adjustment wouldn't be possible.
                    offset += 1
                }

                children.nodes.append(node)
                children.identifierMap[identifier] = index
                children.identifiers.append(identifier)
                children.layoutableChildren.append(
                    LayoutSystem.LayoutableChild(node) { child(element) }
                )
            }

            // TODO: We should be able to reuse unused widgets in newly created nodes.
            // Remove unused widgets, starting from the end of the container for
            // cheaper removals.
            let removalCount = oldNodes.count - oldNodesReused
            if removalCount > 0 {
                for i in (0..<removalCount).reversed() {
                    removeChild(atIndex: children.nodes.count + i)
                }
            }
        }

        // Recompute layoutable children if the last commit cleared them
        if children.layoutableChildren.isEmpty && !children.nodes.isEmpty {
            children.layoutableChildren = zip(children.nodes, elements).map { (node, element) in
                LayoutSystem.LayoutableChild(node) { child(element) }
            }
        }

        return LayoutSystem.computeStackLayout(
            container: widget,
            children: children.layoutableChildren,
            cache: &children.stackLayoutCache,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    /// Returns whether two child views compare equal when the child type
    /// conforms to `Equatable`. Children without an `Equatable` conformance
    /// are conservatively treated as changed (matching eager ``ForEach``
    /// behaviour, which always re-lays-out every row on update).
    private func childViewsEqual(_ a: Child, _ b: Child) -> Bool {
        guard let equatable = a as? any Equatable else {
            return false
        }
        return equatable.isEqual(b)
    }

    /// Lays out only the elements intersecting the scroll viewport (plus an
    /// overscan margin), reporting the estimated full content height so that
    /// the enclosing scroll view sizes its content correctly.
    ///
    /// Only used when the ``ForEach`` sits inside a ``LazyVStack`` within a
    /// vertically scrolling ``ScrollView`` whose backend reports viewport
    /// changes. Reading the viewport's properties here registers an
    /// observation on this view's node, so scrolling re-runs just this
    /// view's layout through the usual machinery.
    @MainActor
    func computeWindowedLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        viewport: ScrollViewport,
        idKeyPath: KeyPath<Items.Element, ID>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let windowedT0 = DispatchTime.now()
        var windowedCreated = 0
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - windowedT0.uptimeNanoseconds) / 1e6
            FileHandle.standardError.write("WLAYOUT off=\(viewport.verticalOffset) created=\(windowedCreated) ms=\(ms)\n".data(using: .utf8)!)
        }

        let offset = max(0, viewport.verticalOffset)
        let viewportHeight = viewport.viewportHeight

        let elementsArray = elements as? [Items.Element] ?? Array(elements)
        let count = elementsArray.count
        // An identical backing buffer implies identical elements (mutation
        // would have triggered copy-on-write), so the identifier map can be
        // reused instead of re-extracting every id per scroll frame.
        var sameBuffer = false
        elementsArray.withUnsafeBufferPointer { buf in
            children.elementsBuffer.withUnsafeBufferPointer { old in
                sameBuffer =
                    buf.baseAddress != nil
                    && buf.baseAddress == old.baseAddress
                    && buf.count == old.count
            }
        }
        let newIDs: [ID]
        if sameBuffer {
            newIDs = children.cachedIDs
        } else {
            newIDs = elementsArray.map { $0[keyPath: idKeyPath] }
            children.cachedIDs = newIDs
            children.elementsBuffer = elementsArray
            children.elementsVersion += 1
        }
        let spacing = environment.layoutSpacing

        if !children.isWindowed {
            children.isWindowed = true
            if !children.nodes.isEmpty {
                // Adopt eagerly materialized nodes into the reuse pool; their
                // widgets are already in the container in element order.
                children.containerIDs = children.identifiers
                for (index, node) in children.nodes.enumerated() {
                    children.nodesByID[children.identifiers[index]] = node
                }
                children.nodes = []
                children.identifierMap = [:]
                children.identifiers = []
                children.layoutableChildren = []
            }
        }

        // Seed the height estimate before any real measurements exist.
        if children.defaultHeight <= 0 {
            children.defaultHeight = 30
        }

        // Cumulative row tops (prefix[i] = top of row i, count+1 entries).
        // Rebuilt lazily when the element list or measured heights change;
        // viewport-only invalidations reuse it, making window computation
        // O(log n) instead of rescanning every element per scroll frame.
        if
            children.prefixHeights.count != count + 1
                || children.prefixVersion != children.heightsVersion
                || children.prefixElementsVersion != children.elementsVersion
        {
            var prefix = [Double](repeating: 0, count: count + 1)
            for i in 0..<count {
                prefix[i + 1] =
                    prefix[i]
                    + (children.measuredHeights[newIDs[i]] ?? children.defaultHeight)
                    + spacing
            }
            children.prefixHeights = prefix
            children.prefixVersion = children.heightsVersion
            children.prefixElementsVersion = children.elementsVersion
            children.prefixDefaultHeight = children.defaultHeight
        }
        let prefix = children.prefixHeights

        func height(ofIndex index: Int) -> Double {
            children.measuredHeights[newIDs[index]] ?? children.defaultHeight
        }

        // Compute the materialization range: elements intersecting the
        // viewport plus one viewport-height (or a bootstrap margin) of
        // overscan on each side.
        let overscan = max(viewportHeight, 600)
        let visLo = max(0, offset - overscan)
        let visHi = offset + viewportHeight + overscan
        var lo = count
        var hi = 0
        if count > 0 {
            // Row i spans [prefix[i], prefix[i+1] - spacing); binary-search
            // the first row whose bottom exceeds visLo and the first whose
            // top reaches visHi.
            var low = 0, high = count
            while low < high {
                let mid = (low + high) / 2
                if prefix[mid + 1] - spacing > visLo { high = mid } else { low = mid + 1 }
            }
            lo = low
            if lo < count {
                var h = count
                var l2 = lo
                while l2 < h {
                    let mid = (l2 + h) / 2
                    if prefix[mid] < visHi { l2 = mid + 1 } else { h = mid }
                }
                hi = l2
            }
        }
        if lo == count {
            // Scrolled past the estimated end; materialize the last overscan's
            // worth of elements so the estimate can be corrected against
            // reality and the viewport still has content to show.
            hi = count
            var back = 0.0
            var i = count
            while i > 0, back < overscan + viewportHeight {
                i -= 1
                back += height(ofIndex: i) + spacing
            }
            lo = i
        }

        // Diff the container's current widget sequence (containerIDs) into
        // the desired window (desiredIDs). Elements leaving the window are
        // evicted from the reuse pool entirely; surviving widgets keep their
        // positions because the desired window is a contiguous slice of the
        // same element order, so the survivors form an ordered subsequence.
        var containerIDs = children.containerIDs
        let desiredIDs = Array(newIDs[lo..<hi])
        let desiredSet = Set(desiredIDs)

        var ci = 0
        while ci < containerIDs.count {
            if desiredSet.contains(containerIDs[ci]) {
                ci += 1
            } else {
                children.queuedChanges.append(.removeChild(ci))
                children.nodesByID.removeValue(forKey: containerIDs[ci])
                children.measuredViews.removeValue(forKey: containerIDs[ci])
                containerIDs.remove(at: ci)
            }
        }

        // Insert the missing ids. After the removals above the surviving
        // widgets are an ordered subsequence of the desired window, so the
        // merge is simply: at each desired index, either the widget is
        // already in place or it must be inserted there.
        for (i, id) in desiredIDs.enumerated() {
            if i < containerIDs.count, containerIDs[i] == id {
                continue
            }
            let element = elementsArray[lo + i]
            var maybeNode = children.nodesByID[id]
            if maybeNode == nil {
                windowedCreated += 1
                maybeNode = AnyViewGraphNode(
                    for: child(element),
                    backend: backend,
                    environment: environment
                )
            }
            let node = maybeNode!
            children.queuedChanges.append(.insertChild(node.widget, i))
            containerIDs.insert(id, at: i)
            children.nodesByID[id] = node
        }
        children.containerIDs = containerIDs

        // Record the materialized window for `commit`, which is where the
        // children actually get laid out. Layout probes only need the size
        // estimate computed below, so probing passes don't touch the
        // children at all.
        children.windowedNodes = desiredIDs.compactMap { children.nodesByID[$0] }
        children.windowedElements = elementsArray
        children.windowedLo = lo

        // The estimated total height from the most recently measured row
        // heights; the scroll view sizes its content against this.
        let total = count > 0 ? max(0, prefix[count] - spacing) : 0

        return ViewLayoutResult(
            size: ViewSize(
                proposedSize.width ?? children.maxMeasuredWidth,
                total
            ),
            childResults: [],
            participateInStackLayoutsWhenEmpty: !desiredIDs.isEmpty
        )
    }

    @MainActor
    func deprecatedUpdate<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        @inline(__always)
        func insertChild(_ child: Backend.Widget, atIndex index: Int) {
            children.queuedChanges.append(.insertChild(AnyWidget(child), index))
        }

        @inline(__always)
        func removeChild(atIndex index: Int) {
            children.queuedChanges.append(.removeChild(index))
        }

        let elementsStartIndex = elements.startIndex

        var layoutableChildren: [LayoutSystem.LayoutableChild] = []
        for (i, node) in children.nodes.enumerated() {
            guard i < elements.count else {
                break
            }
            let index = elements.index(elementsStartIndex, offsetBy: i)
            if children.isFirstUpdate {
                insertChild(node.widget.into(), atIndex: i)
            }
            let layoutableChild = LayoutSystem.LayoutableChild(node) { child(elements[index]) }
            layoutableChildren.append(layoutableChild)
        }
        children.isFirstUpdate = false

        let nodeCount = children.nodes.count
        let remainingElementCount = elements.count - nodeCount
        if remainingElementCount > 0 {
            let startIndex = elements.index(elementsStartIndex, offsetBy: nodeCount)
            for i in 0..<remainingElementCount {
                let element = elements[elements.index(startIndex, offsetBy: i)]
                let node = AnyViewGraphNode(
                    for: child(element),
                    backend: backend,
                    environment: environment
                )
                insertChild(node.widget.into(), atIndex: children.nodes.count)
                children.nodes.append(node)
                let layoutableChild = LayoutSystem.LayoutableChild(node) { child(element) }
                layoutableChildren.append(layoutableChild)
            }
        } else if remainingElementCount < 0 {
            let unusedCount = -remainingElementCount
            for i in 0..<unusedCount {
                removeChild(atIndex: nodeCount - i - 1)
            }
            children.nodes.removeLast(unusedCount)
        }

        children.layoutableChildren = layoutableChildren

        return LayoutSystem.computeStackLayout(
            container: widget,
            children: layoutableChildren,
            cache: &children.stackLayoutCache,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        for change in children.queuedChanges {
            switch change {
                case .insertChild(let child, let index):
                    backend.insert(child.into(), into: widget, at: index)
                case .removeChild(let index):
                    backend.remove(childAt: index, from: widget)
                case .swapChildren(let firstIndex, let secondIndex):
                    backend.swap(childAt: firstIndex, withChildAt: secondIndex, in: widget)
            }
        }
        children.queuedChanges = []

        if children.isWindowed {
            backend.setSize(of: widget, to: layout.size.vector)

            let commitT0 = DispatchTime.now()
            var commitLaidOut = 0

            // Lay out each materialized row at the committed width, now that
            // the final size is known (probes only used size estimates). Rows
            // whose child view compares equal to the one from the previous
            // commit are skipped (EquatableView semantics); rows with a
            // non-Equatable child type are always re-laid-out.
            let rowWidth = layout.size.width
            let rowProposal = ProposedViewSize(rowWidth, nil)
            let widthChanged = children.measuredAtWidth != rowWidth
            children.measuredAtWidth = rowWidth
            let elementsArray = children.windowedElements
            var measured: [ID: Double] = [:]
            var maxWidth = 0.0
            var heightDelta = 0.0
            for (i, node) in children.windowedNodes.enumerated() {
                let id = children.containerIDs[i]
                let element = elementsArray[children.windowedLo + i]
                let childView = child(element)
                let canSkip = !widthChanged
                    && children.measuredViews[id] != nil
                    && childViewsEqual(children.measuredViews[id]!, childView)
                    && children.measuredHeights[id] != nil
                let staleHeight = children.measuredHeights[id] ?? children.prefixDefaultHeight
                if canSkip {
                    let height = children.measuredHeights[id]!
                    measured[id] = height
                    heightDelta += height - staleHeight
                    maxWidth = max(maxWidth, children.measuredWidths[id] ?? 0)
                    continue
                }
                if let prev = children.measuredViews[id], !childViewsEqual(prev, childView) {
                    FileHandle.standardError.write(
                        "VIEQ-FALSE id=\(id)\n".data(using: .utf8)!
                    )
                }
                commitLaidOut += 1
                _ = node.computeLayout(
                    with: childView,
                    proposedSize: rowProposal,
                    environment: environment
                )
                let result = node.commit()
                measured[id] = result.size.height
                heightDelta += result.size.height - staleHeight
                children.measuredViews[id] = childView
                children.measuredWidths[id] = result.size.width
                maxWidth = max(maxWidth, result.size.width)
            }
            let previousDefault = children.defaultHeight
            let previousMeasuredCount = children.measuredHeights.count
            children.measuredHeights.merge(measured) { _, new in new }
            if !children.measuredHeights.isEmpty {
                children.defaultHeight =
                    children.measuredHeights.values.reduce(0, +)
                    / Double(children.measuredHeights.count)
            }
            children.maxMeasuredWidth = max(children.maxMeasuredWidth, maxWidth)
            // Invalidate the prefix cache only when the merge actually
            // changed a row height, added a measurement, or moved the
            // default — steady-state scrolling then keeps O(log n) passes.
            if heightDelta != 0
                || children.measuredHeights.count != previousMeasuredCount
                || children.defaultHeight != previousDefault
            {
                children.heightsVersion += 1
            }

            // Position the materialized rows at their absolute offsets within
            // the full content. Rows above the materialization window were
            // not re-measured this pass, so the cached prefix sum still
            // gives the window's top directly; walking only materialized
            // rows keeps this O(window) instead of O(element count).
            let alignment = environment.layoutAlignment
            let spacing = environment.layoutSpacing
            var cursor =
                children.windowedLo < children.prefixHeights.count
                ? children.prefixHeights[children.windowedLo]
                : 0.0
            for nodeIndex in children.windowedNodes.indices {
                let id = children.containerIDs[nodeIndex]
                var position = Position.zero
                switch alignment {
                    case .leading:
                        position.x = 0
                    case .center:
                        position.x = (layout.size.width - (children.measuredWidths[id] ?? 0)) / 2
                    case .trailing:
                        position.x = layout.size.width - (children.measuredWidths[id] ?? 0)
                }
                position.y = cursor
                backend.setPosition(ofChildAt: nodeIndex, in: widget, to: position.vector)
                cursor += (children.measuredHeights[id] ?? children.defaultHeight) + spacing
            }

            // `layout.size` was computed before the rows' real heights were
            // known (unmeasured rows contribute `defaultHeight` estimates).
            // The corrected total is the prefix-sum total plus each
            // materialized row's (fresh − stale) height delta; rows outside
            // the window kept their heights so they don't contribute.
            let prefixTotal =
                children.prefixHeights.count == elementsArray.count + 1
                ? children.prefixHeights[elementsArray.count]
                : layout.size.height
            let correctedHeight = max(0, prefixTotal - spacing + heightDelta)
            if correctedHeight != layout.size.height {
                environment.onResize(ViewSize(layout.size.width, correctedHeight))
            }

            let commitMs = Double(DispatchTime.now().uptimeNanoseconds - commitT0.uptimeNanoseconds) / 1e6
            FileHandle.standardError.write(
                "WCOMMIT nodes=\(children.windowedNodes.count) laidOut=\(commitLaidOut) ms=\(commitMs)\n"
                    .data(using: .utf8)!
            )
            return
        }

        LayoutSystem.commitStackLayout(
            container: widget,
            children: children.layoutableChildren,
            cache: &children.stackLayoutCache,
            layout: layout,
            environment: environment,
            backend: backend
        )

        // Reset layoutable children cache so that we recompute them during the
        // next update cycle. This is important at the moment because the `child`
        // closure and `elements` array may have changed. In future we'll separate
        // view body recomputation from the computeLayout step, which should simplify
        // things.
        children.layoutableChildren = []
    }
}

/// Stores the child nodes of a ``ForEach`` view.
///
/// Also handles the ``ForEach`` view's widget unlike most ``ViewGraphNodeChildren``
/// implementations. This logic could mostly be moved into ``ForEach`` but it would still
/// be accessing ``ForEachViewChildren/storage`` so it'd just introduce an extra layer of
/// property accesses. It also means that the complexity is in a single type instead of
/// split across two.
///
/// Most of the complexity comes from resizing the list widget and moving around elements
/// when elements are added/removed.
class ForEachViewChildren<
    Items: Collection,
    ID: Hashable,
    Child: View
>: ViewGraphNodeChildren {
    /// The nodes for all current children of the ``ForEach`` view.
    var nodes: [AnyViewGraphNode<Child>] = []

    /// A map from element identifier to node index.
    var identifierMap: [ID: Int]

    /// The identifiers corresponding to ``nodes``.
    var identifiers: [ID]

    /// Changes queued during computeLayout.
    var queuedChanges: [Change] = []

    /// A queued widget operation to perform during `ForEach.commit`.
    enum Change: CustomStringConvertible {
        case insertChild(AnyWidget, Int)
        case removeChild(Int)
        case swapChildren(Int, Int)

        var description: String {
            switch self {
                case .insertChild(let widget, let index):
                    "Insert widget \(ObjectIdentifier(widget.widget as AnyObject)) at \(index)"
                case .removeChild(let index):
                    "Remove widget at \(index)"
                case .swapChildren(let firstIndex, let secondIndex):
                    "Swap widgets at \(firstIndex) and \(secondIndex)"
            }
        }
    }

    /// Only used by ``ForEach/deprecatedUpdate(_:children:proposedSize:environment:backend:)``.
    var isFirstUpdate = true

    /// A cache of the view's children, used when the ForEach's element
    /// identifiers haven't changed since the previous layout computation.
    var layoutableChildren: [LayoutSystem.LayoutableChild] = []

    // MARK: Windowed mode

    /// Whether this ForEach is materializing only the elements near the
    /// scroll viewport (see ``ForEach/computeWindowedLayout``).
    var isWindowed = false
    /// The identifiers of the widgets currently in the container, in display
    /// order. Only populated in windowed mode.
    var containerIDs: [ID] = []
    /// The materialized nodes, keyed by element identifier. In windowed mode
    /// this pool contains exactly the nodes whose widgets are in the
    /// container.
    var nodesByID: [ID: AnyViewGraphNode<Child>] = [:]
    /// The materialized nodes in display order, parallel to ``containerIDs``.
    var windowedNodes: [AnyViewGraphNode<Child>] = []
    /// The element list snapshot used by the windowed `commit` pass.
    var windowedElements: [Items.Element] = []
    /// The index of the first materialized element within ``windowedElements``.
    var windowedLo = 0
    /// Measured heights of materialized elements, keyed by identifier.
    /// Retained across window shifts so that offset estimates converge.
    var measuredHeights: [ID: Double] = [:]
    /// The height assumed for elements that haven't been measured yet.
    var defaultHeight = 0.0
    /// The widest measured row width, used as the ForEach's width when the
    /// proposal doesn't specify one.
    var maxMeasuredWidth = 0.0
    /// The child view most recently committed for each identifier. Compared
    /// dynamically (when `Child` is `Equatable`) to skip re-laying-out rows
    /// whose view hasn't changed since the previous commit.
    var measuredViews: [ID: Child] = [:]
    /// The measured width of each row at the current row width.
    var measuredWidths: [ID: Double] = [:]
    /// The row width that ``measuredViews``/``measuredWidths`` were
    /// recorded at. A change forces re-measuring every materialized row.
    var measuredAtWidth = 0.0

    /// Cumulative row-top offsets (count+1 entries) cached between
    /// layout passes so viewport-only invalidations don't rescan the
    /// element list. Row `i` spans `[prefixHeights[i],
    /// prefixHeights[i+1] - spacing)`.
    var prefixHeights: [Double] = []
    /// The ``heightsVersion`` ``prefixHeights`` was built at.
    var prefixVersion = -1
    /// The ``elementsVersion`` ``prefixHeights`` was built at.
    var prefixElementsVersion = -1
    /// The ``defaultHeight`` used when ``prefixHeights`` was built; the
    /// stale-height baseline for unmeasured rows.
    var prefixDefaultHeight = 0.0
    /// Bumped whenever measured row heights or ``defaultHeight`` may
    /// have changed, invalidating ``prefixHeights``.
    var heightsVersion = 0
    /// Bumped whenever the element list's backing storage changes.
    var elementsVersion = 0
    /// Identifier extraction cache, keyed by element-array buffer
    /// identity so viewport-only passes skip re-mapping every element.
    var cachedIDs: [ID] = []
    /// The array whose buffer ``cachedIDs`` was extracted from; held to
    /// keep the buffer (and its identity) stable across passes.
    var elementsBuffer: [Items.Element] = []

    var widgets: [AnyWidget] {
        (isWindowed ? windowedNodes : nodes).map(\.widget)
    }

    // TODO: This pattern of erasing by wrapping in a temporary class seems
    //   inefficient. Could ErasedViewGraphNode maybe be a struct instead?
    var erasedNodes: [ErasedViewGraphNode] {
        (isWindowed ? windowedNodes : nodes).map(ErasedViewGraphNode.init(wrapping:))
    }

    var stackLayoutCache = StackLayoutCache.initial

    init<Backend: BaseAppBackend>(
        from view: ForEach<Items, ID, Child>,
        backend: Backend,
        idKeyPath: KeyPath<Items.Element, ID>?,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        identifierMap = [:]
        identifiers = []

        if idKeyPath == nil {
            // Deprecated code path. I'm not touching this anymore cause it's
            // gonna get deleted before any proper release.
            nodes = view.elements
                .map(view.child)
                .enumerated()
                .map { (index, child) in
                    let snapshot = index < snapshots?.count ?? 0 ? snapshots?[index] : nil
                    return ViewGraphNode(
                        for: child,
                        backend: backend,
                        snapshot: snapshot,
                        environment: environment
                    )
                }
                .map(AnyViewGraphNode.init(_:))
        } else {
            nodes = []
        }
    }
}

extension Equatable {
    /// Compares this value to a dynamically-typed value, used by ``ForEach``'s
    /// windowed layout to detect unchanged elements without requiring an
    /// `Equatable` constraint on the element type.
    fileprivate func isEqual(_ other: Any) -> Bool {
        (other as? Self) == self
    }
}

extension ForEach where ID == Int {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *,
        deprecated,
        renamed: "init(_:id:_:)",
        message: """
            ForEach requires an explicit 'id' parameter for non-Identifiable \
            elements to correctly persist state across view updates
            """
    )
    @_disfavoredOverload
    public init(
        _ elements: Items,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = nil
    }
}

extension ForEach where Items.Element: Identifiable, ID == Items.Element.ID {
    /// Creates a view that creates child views on demand based on a collection of identifiable data.
    public init(
        _ elements: Items,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = \.id
    }
}

// MARK: Deprecated MenuItem-based inits

extension ForEach where ID == Int {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *,
        deprecated,
        message: """
            ForEach requires an explicit 'id' parameter for non-Identifiable \
            elements to correctly persist state across view updates
            """
    )
    @_disfavoredOverload
    public init(
        menuItems elements: Items,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = nil
    }
}

extension ForEach {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *,
        deprecated,
        renamed: "init(_:id:_:)",
        message: """
            Special treatment of menu item ForEach blocks is no longer necessary. \
            Remove the menuItems parameter label.
            """
    )
    public init(
        menuItems elements: Items,
        id keyPath: KeyPath<Items.Element, ID>,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = keyPath
    }
}

extension ForEach where Items.Element: Identifiable, ID == Items.Element.ID {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *,
        deprecated,
        renamed: "init(_:_:)",
        message: """
            Special treatment of menu item ForEach blocks is no longer necessary. \
            Remove the menuItems parameter label.
            """
    )
    public init(
        menuItems elements: Items,
        @ViewBuilder _ child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = \.id
    }
}
