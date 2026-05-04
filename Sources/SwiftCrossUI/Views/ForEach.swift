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
        let container = backend.createContainer()
        if idKeyPath == nil {
            // Deprecated code path. We've centralised the new implementation
            // into computeLayout and commit.
            for (index, node) in children.nodes.enumerated() {
                backend.insert(node.getWidget().into(), into: container, at: index)
            }
        }
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
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

        children.updateGeneration += 1
        let generation = children.updateGeneration
        let oldActiveKeys = children.activeKeys
        let oldRenderKeys = children.renderKeys
        var newActiveKeys: [Children.ItemKey] = []
        var newActiveKeySet = Set<Children.ItemKey>()
        var occurrenceCounts: [ID: Int] = [:]
        var warnedDuplicateIdentifiers = Set<ID>()

        for element in elements {
            let identifier = element[keyPath: idKeyPath]
            let occurrence = occurrenceCounts[identifier, default: 0]
            occurrenceCounts[identifier] = occurrence + 1
            let key = Children.ItemKey(identifier: identifier, occurrence: occurrence)
            let childContent = child(element)
            let childView = AnyView(childContent)
            let explicitTransition = _optionalTransitionTrait(of: childContent)
            let childTransition = explicitTransition ?? .opacity
            let usesTransition = true

            if occurrence > 0 && warnedDuplicateIdentifiers.insert(identifier).inserted {
                logger.warning(
                    "duplicate identifier in ForEach; view state may not act as you would expect",
                    metadata: ["identifier": "\(identifier)"]
                )
            }

            if let item = children.items[key] {
                item.view = childView
                item.transition = childTransition
                item.usesTransition = usesTransition
                item.generation = generation
                item.isRemovalScheduled = false
                if item.phase == .didDisappear {
                    item.phase = .identity
                }
            } else {
                let shouldTransition = usesTransition
                    && children.hasMounted
                    && childTransition.duration(for: environment.transaction) > 0
                let initialPhase = shouldTransition ? TransitionPhase.willAppear : .identity
                let nodeView = !usesTransition && initialPhase == .identity
                    ? childView
                    : transitioned(
                        childView,
                        phase: initialPhase,
                        transition: childTransition
                    )
                let node = ErasedViewGraphNode(
                    for: nodeView,
                    backend: backend,
                    environment: environment
                )
                let item = Children.Item(
                    key: key,
                    node: node,
                    view: childView,
                    transition: childTransition,
                    usesTransition: usesTransition,
                    phase: initialPhase,
                    generation: generation
                )
                children.items[key] = item
            }

            newActiveKeys.append(key)
            newActiveKeySet.insert(key)
        }

        for key in Array(children.items.keys) {
            guard let item = children.items[key] else {
                continue
            }
            if newActiveKeySet.contains(key) {
                continue
            }
            if item.phase == .didDisappear {
                continue
            }
            let shouldTransition = item.usesTransition
                && children.hasMounted
                && item.transition.duration(for: environment.transaction) > 0
            if shouldTransition {
                item.phase = .didDisappear
                item.generation = generation
                item.removalGeneration += 1
                item.isRemovalScheduled = false
            } else {
                children.items[key] = nil
                LayoutPresentationStore.shared.removePosition(for: item.animationID)
            }
        }

        let removalKeys = oldRenderKeys.filter { key in
            guard let item = children.items[key] else {
                return false
            }
            return item.phase == .didDisappear && !newActiveKeySet.contains(key)
        }

        var renderKeys = newActiveKeys
        for key in removalKeys {
            guard !renderKeys.contains(key) else {
                continue
            }
            renderKeys.append(key)
        }

        children.activeKeys = newActiveKeys
        children.renderKeys = renderKeys
        children.syncLegacyFields()

        if oldActiveKeys != newActiveKeys {
            children.stackLayoutCache = .initial
        }
        if oldRenderKeys != children.renderKeys {
            children.needsWidgetSync = true
        }

        children.layoutableKeys = []
        children.layoutableChildren = newActiveKeys.compactMap { key in
            guard let item = children.items[key] else {
                return nil
            }
            children.layoutableKeys.append(key)
            return layoutableChild(
                for: item,
                phase: item.phase,
                environment: environment
            )
        }
        children.removalLayoutableChildren = removalKeys.compactMap { key in
            children.items[key].map { item in
                layoutableChild(
                    for: item,
                    phase: item.phase,
                    environment: environment
                )
            }
        }
        children.removalLayoutKeys = removalKeys

        let result = LayoutSystem.computeStackLayout(
            container: widget,
            children: children.layoutableChildren,
            cache: &children.stackLayoutCache,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
        for child in children.removalLayoutableChildren {
            _ = child.computeLayout(
                proposedSize: proposedSize,
                environment: environment
            )
        }
        return result
    }

    @MainActor
    private func transitioned(
        _ view: AnyView,
        phase: TransitionPhase,
        transition: AnyTransition
    ) -> AnyView {
        transition.applyTransition(view, phase)
    }

    @MainActor
    private func layoutableChild(
        for item: Children.Item,
        phase: TransitionPhase,
        environment: EnvironmentValues
    ) -> LayoutSystem.LayoutableChild {
        LayoutSystem.LayoutableChild(
            computeLayout: { proposedSize, proposedEnvironment in
                let view = !item.usesTransition && phase == .identity
                    ? item.view
                    : transitioned(
                        item.view,
                        phase: phase,
                        transition: item.transition
                    )
                let environment = !item.usesTransition && phase == .identity
                    ? proposedEnvironment
                    : transitionEnvironment(
                        transition: item.transition,
                        environment: proposedEnvironment
                    )
                return item.node.computeLayoutWithNewView(
                    view,
                    proposedSize,
                    environment
                ).size
            },
            commit: {
                item.node.commit()
            },
            animationID: item.animationID
        )
    }

    private func transitionEnvironment(
        transition: AnyTransition,
        environment: EnvironmentValues
    ) -> EnvironmentValues {
        var transaction = environment.transaction
        if !transaction.disablesAnimations {
            transaction.animation = transition.animation(for: transaction)
        }
        return environment.withCurrentTransaction(transaction)
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

        // TODO: The way we're reusing nodes for technically different elements means that if
        //   Child has state of its own then it could get pretty confused thinking that its state
        //   changed whereas it was actually just moved to a new slot in the array. Probably not
        //   a huge issue, but definitely something to keep an eye on.
        var layoutableChildren: [LayoutSystem.LayoutableChild] = []
        for (i, node) in children.nodes.enumerated() {
            guard i < elements.count else {
                break
            }
            let index = elements.index(elementsStartIndex, offsetBy: i)
            if children.isFirstUpdate {
                insertChild(node.getWidget().into(), atIndex: i)
            }
            let layoutableChild = LayoutSystem.LayoutableChild(node) {
                child(elements[index])
            }
            layoutableChildren.append(layoutableChild)
        }
        children.isFirstUpdate = false

        let nodeCount = children.nodes.count
        let remainingElementCount = elements.count - nodeCount
        if remainingElementCount > 0 {
            let startIndex = elements.index(elementsStartIndex, offsetBy: nodeCount)
            for i in 0..<remainingElementCount {
                let element = elements[elements.index(startIndex, offsetBy: i)]
                let node = ErasedViewGraphNode(
                    for: child(element),
                    backend: backend,
                    environment: environment
                )
                insertChild(node.getWidget().into(), atIndex: children.nodes.count)
                children.nodes.append(node)
                let layoutableChild = LayoutSystem.LayoutableChild(node) {
                    child(element)
                }
                layoutableChildren.append(layoutableChild)
            }
        } else if remainingElementCount < 0 {
            let unusedCount = -remainingElementCount
            for i in 0..<unusedCount {
                removeChild(atIndex: nodeCount - i - 1)
            }
            children.nodes.removeLast(unusedCount)
        }

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
            }
        }
        children.queuedChanges = []
        syncRenderedWidgets(widget, children: children, backend: backend)

        if children.hasMounted {
            for key in children.activeKeys {
                guard
                    let item = children.items[key],
                    let lastPosition = item.lastPosition
                else {
                    continue
                }
                LayoutPresentationStore.shared.seedPositionIfNeeded(
                    for: item.animationID,
                    position: lastPosition
                )
            }
        }

        let activeChildIndices = children.layoutableKeys.compactMap { key in
            children.committedRenderKeys.firstIndex(of: key)
        }
        guard activeChildIndices.count == children.layoutableChildren.count else {
            logger.warning("ForEach skipped commit with stale child indices")
            children.needsWidgetSync = true
            requestGraphUpdate(
                children: children,
                environment: environment,
                backend: backend
            )
            return
        }

        let activePositions = LayoutSystem.commitStackLayout(
            container: widget,
            children: children.layoutableChildren,
            cache: &children.stackLayoutCache,
            layout: layout,
            environment: environment,
            backend: backend,
            childIndices: activeChildIndices
        )
        for (key, position) in zip(children.layoutableKeys, activePositions) {
            children.items[key]?.lastPosition = position
        }

        for (index, child) in children.removalLayoutableChildren.enumerated() {
            guard
                index < children.removalLayoutKeys.count,
                let item = children.items[children.removalLayoutKeys[index]],
                let renderIndex = children.committedRenderKeys.firstIndex(of: item.key)
            else {
                continue
            }
            _ = child.commit()
            backend.setPosition(
                ofChildAt: renderIndex,
                in: widget,
                to: (item.lastPosition ?? .zero).vector
            )
        }

        scheduleRemovalsIfNeeded(
            widget,
            children: children,
            environment: environment,
            backend: backend
        )
        scheduleInsertionUpdateIfNeeded(
            children: children,
            environment: environment,
            backend: backend
        )

        children.hasMounted = true
    }

    @MainActor
    private func syncRenderedWidgets<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        backend: Backend
    ) {
        guard children.needsWidgetSync
            || children.committedRenderKeys != children.renderKeys
        else {
            return
        }

        let current = children.committedRenderKeys
        let target = children.renderKeys

        var insertedKeys: [Children.ItemKey] = []
        if current != target {
            backend.removeAllChildren(of: widget)
            for key in target {
                guard let child = children.items[key]?.node.getWidget() else {
                    continue
                }
                backend.insert(child.into(), into: widget, at: insertedKeys.count)
                insertedKeys.append(key)
            }
        } else {
            insertedKeys = target
        }

        children.committedRenderKeys = insertedKeys
        children.needsWidgetSync = false
    }

    @MainActor
    private func scheduleInsertionUpdateIfNeeded<Backend: BaseAppBackend>(
        children: Children,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        var hasInsertion = false
        for key in children.activeKeys {
            guard let item = children.items[key], item.phase == .willAppear else {
                continue
            }
            item.phase = .identity
            hasInsertion = true
        }

        guard hasInsertion else {
            return
        }

        children.stackLayoutCache = .initial
        let transaction = environment.transaction
        requestGraphUpdate(
            children: children,
            environment: environment.withCurrentTransaction(transaction),
            backend: backend
        )
    }

    @MainActor
    private func scheduleRemovalsIfNeeded<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let removalItems = children.renderKeys.compactMap { key -> Children.Item? in
            guard
                let item = children.items[key],
                item.phase == .didDisappear
            else {
                return nil
            }
            return item
        }
        guard !removalItems.isEmpty else {
            return
        }

        for item in removalItems {
            guard !item.isRemovalScheduled else {
                continue
            }
            item.isRemovalScheduled = true
            let generation = item.removalGeneration
            let key = item.key
            let duration = item.transition.duration(
                for: environment.transaction
            )
            let remove: @MainActor @Sendable () -> Void = {
                guard
                    let item = children.items[key],
                    item.phase == .didDisappear,
                    item.removalGeneration == generation
                else {
                    return
                }
                children.items[key] = nil
                LayoutPresentationStore.shared.removePosition(for: item.animationID)
                children.renderKeys.removeAll { $0 == key }
                children.removalLayoutKeys.removeAll { $0 == key }
                children.needsWidgetSync = true
                children.syncLegacyFields()
                children.stackLayoutCache = .initial
                requestGraphUpdate(
                    children: children,
                    environment: environment,
                    backend: backend
                )
            }

            guard duration > 0 else {
                remove()
                continue
            }

            guard let graphUpdateHost = environment.graphUpdateHost else {
                backend.runInMainThread {
                    remove()
                }
                continue
            }

            graphUpdateHost.enqueueAfter(
                backend: backend,
                delay: duration,
                transaction: environment.transaction,
                key: AnyHashable(key),
                action: remove
            )
        }
    }

    @MainActor
    private func requestGraphUpdate<Backend: BaseAppBackend>(
        children: Children,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let transaction = environment.transaction
        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread {
                withTransaction(transaction) {
                    StateMutationContext.withTransaction(transaction) {
                        environment.onResize(.zero)
                    }
                }
            }
            return
        }

        graphUpdateHost.enqueue(
            backend: backend,
            transaction: transaction,
            key: AnyHashable(ObjectIdentifier(children))
        ) {
            environment.onResize(.zero)
        }
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
    var nodes: [ErasedViewGraphNode] = []

    /// A map from element identifier to node index.
    var identifierMap: [ID: Int]

    /// The identifiers corresponding to ``nodes``.
    var identifiers: [ID]

    var items: [ItemKey: Item] = [:]
    var activeKeys: [ItemKey] = []
    var renderKeys: [ItemKey] = []
    var committedRenderKeys: [ItemKey] = []
    var removalLayoutKeys: [ItemKey] = []
    var updateGeneration = 0
    var hasMounted = false
    var needsWidgetSync = false

    /// Changes queued during computeLayout.
    var queuedChanges: [Change] = []

    /// A queued widget operation to perform during `ForEach.commit`.
    enum Change: CustomStringConvertible {
        case insertChild(AnyWidget, Int)
        case removeChild(Int)

        var description: String {
            switch self {
                case .insertChild(let widget, let index):
                    "Insert widget \(ObjectIdentifier(widget.widget as AnyObject)) at \(index)"
                case .removeChild(let index):
                    "Remove widget at \(index)"
            }
        }
    }

    /// Only used by ``ForEach/deprecatedUpdate(_:children:proposedSize:environment:backend:)``.
    var isFirstUpdate = true

    var layoutableKeys: [ItemKey] = []
    var layoutableChildren: [LayoutSystem.LayoutableChild] = []
    var removalLayoutableChildren: [LayoutSystem.LayoutableChild] = []

    var widgets: [AnyWidget] {
        renderKeys.compactMap { key in
            items[key]?.node.getWidget()
        }
    }

    // TODO: This pattern of erasing by wrapping in a temporary class seems
    //   inefficient. Could ErasedViewGraphNode maybe be a struct instead?
    var erasedNodes: [ErasedViewGraphNode] {
        renderKeys.compactMap { key in
            items[key]?.node
        }
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
                    return ErasedViewGraphNode(
                        for: child,
                        backend: backend,
                        snapshot: snapshot,
                        environment: environment
                    )
                }
        } else {
            nodes = []
        }
    }

    struct ItemKey: Hashable {
        var identifier: ID
        var occurrence: Int
    }

    final class Item {
        var key: ItemKey
        var node: ErasedViewGraphNode
        var view: AnyView
        var transition: AnyTransition
        var usesTransition: Bool
        var phase: TransitionPhase
        var generation: Int
        let animationID: ObjectIdentifier
        var removalGeneration = 0
        var isRemovalScheduled = false
        var lastPosition: Position?

        @MainActor
        init(
            key: ItemKey,
            node: ErasedViewGraphNode,
            view: AnyView,
            transition: AnyTransition,
            usesTransition: Bool,
            phase: TransitionPhase,
            generation: Int
        ) {
            self.key = key
            self.node = node
            self.view = view
            self.transition = transition
            self.usesTransition = usesTransition
            self.phase = phase
            self.generation = generation
            animationID = ObjectIdentifier(node.getWidget().widget as AnyObject)
        }
    }

    func syncLegacyFields() {
        nodes = activeKeys.compactMap { key in
            items[key]?.node
        }
        identifiers = activeKeys.map(\.identifier)
        identifierMap = [:]
        for (index, key) in activeKeys.enumerated()
        where key.occurrence == 0 {
            identifierMap[key.identifier] = index
        }
    }
}

extension ForEach where ID == Int {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *, deprecated, renamed: "init(_:id:_:)",
        message:
            "ForEach requires an explicit 'id' parameter for non-Identifiable elements to correctly persist state across view updates"
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

extension ForEach where Child == [MenuItem], ID == Int {
    /// Creates a view that creates child views on demand based on a collection of data.
    @available(
        *,
        deprecated,
        message:
            "ForEach requires an explicit 'id' parameter for non-Identifiable elements to correctly persist state across view updates"
    )
    @_disfavoredOverload
    public init(
        menuItems elements: Items,
        @MenuItemsBuilder _ child: @escaping (Items.Element) -> [MenuItem]
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = nil
    }
}

extension ForEach where Child == [MenuItem] {
    /// Creates a view that creates child views on demand based on a collection of data.
    public init(
        menuItems elements: Items,
        id keyPath: KeyPath<Items.Element, ID>,
        @MenuItemsBuilder _ child: @escaping (Items.Element) -> [MenuItem]
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = keyPath
    }
}

extension ForEach where Items.Element: Identifiable, Child == [MenuItem], ID == Items.Element.ID {
    /// Creates a view that creates child views on demand based on a collection of data.
    public init(
        menuItems elements: Items,
        @MenuItemsBuilder _ child: @escaping (Items.Element) -> [MenuItem]
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = \.id
    }
}

extension ForEach where Items.Element: Identifiable, ID == Items.Element.ID {
    /// Creates a view that creates child views on demand based on a collection of identifiable data.
    public init(
        _ elements: Items,
        child: @escaping (Items.Element) -> Child
    ) {
        self.elements = elements
        self.child = child
        self.idKeyPath = \.id
    }
}
