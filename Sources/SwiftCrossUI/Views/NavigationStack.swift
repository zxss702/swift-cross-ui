import Foundation

/// Type to indicate the root of the NavigationStack. This is internal to prevent root accidentally showing instead
/// of a detail view.
fileprivate struct NavigationStackRootPath: Codable {}

/// A view that displays a root view and enables you to present additional views
/// over the root view.
///
/// Use ``navigationDestination(for:destination:)`` on this view instead of its
/// children, unlike Apple's SwiftUI API.
<<<<<<< Updated upstream
public struct NavigationStack<Detail: View>: View {
    public var body: some View {
        if let element = elements.last {
            if let content = child(element) {
                content
            } else {
                fatalError(
                    "Failed to find detail view for \"\(element)\", make sure you have called .navigationDestination for this type."
                )
            }
        } else {
            Text("Empty navigation path")
        }
    }
=======
public struct NavigationStack<Detail: View>: TypeSafeView, View, ObservationTrackingView {
    typealias Children = NavigationStackChildren<Detail>

    public var body = EmptyView()
>>>>>>> Stashed changes

    @State private var ownedPath = NavigationPath()

    /// A binding to the externally controlled navigation path, if one was
    /// supplied by the caller.
    fileprivate var pathBinding: Binding<NavigationPath>?
    /// A binding to the current navigation path.
    fileprivate var path: Binding<NavigationPath> {
        pathBinding ?? $ownedPath
    }
    /// The types handled by each destination (in the same order as their
    /// corresponding views in the stack).
    fileprivate var destinationTypes: [any Codable.Type]
    /// Gets a recursive ``EitherView`` structure which will have a single view
    /// visible suitable for displaying the given path element (based on its
    /// type).
    ///
    /// It's implemented as a recursive structure because that's the best way to keep this
    /// typesafe without introducing some crazy generated pseudo-variadic storage types of
    /// some sort. This way we can easily have unlimited navigation destinations and there's
    /// just a single simple method for adding a navigation destination.
    fileprivate var child: (any Codable) -> Detail?
    /// The elements of the navigation path. The result can depend on
    /// ``NavigationStack/destinationTypes`` which determines how the keys are
    /// decoded if they haven't yet been decoded (this happens if they're loaded
    /// from disk for persistence).
    fileprivate var elements: [any Codable] {
        let resolvedPath = path.wrappedValue.path(
            destinationTypes: destinationTypes
        )
        return [NavigationStackRootPath()] + resolvedPath
    }

    /// Creates a navigation stack with heterogeneous navigation state that you
    /// can control.
    ///
    /// - Parameters:
    ///   - path: A ``Binding`` to the navigation state for this stack.
    ///   - root: The view to display when the stack is empty.
    public init(
        path: Binding<NavigationPath>,
        @ViewBuilder _ root: @escaping () -> Detail
    ) {
        self.pathBinding = path
        destinationTypes = []
        child = { element in
            if element is NavigationStackRootPath {
                return root()
            } else {
                return nil
            }
        }
    }

    /// Creates a navigation stack with local heterogeneous navigation state.
    ///
    /// Use this initializer when the stack can own its own path. Use
    /// ``init(path:_:)`` when the path needs to be persisted or controlled by
    /// another view model.
    public init(@ViewBuilder _ root: @escaping () -> Detail) {
        pathBinding = nil
        destinationTypes = []
        child = { element in
            if element is NavigationStackRootPath {
                return root()
            } else {
                return nil
            }
        }
    }

    /// Associates a destination view with a presented data type for use within
    /// a navigation stack.
    ///
    /// Add this view modifer to describe the view that the stack displays when
    /// presenting a particular kind of data. Use a ``NavigationLink`` to
    /// present the data. You can add more than one navigation destination
    /// modifier to the stack if it needs to present more than one kind of data.
    ///
    /// - Parameters:
    ///   - data: The type of data that this destination matches.
    ///   - destination: A view builder that defines a view to display when the
    ///     stack's navigation state contains a value of type data. The closure
    ///     takes one argument, which is the value of the data to present.
    public func navigationDestination<D: Codable, C: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        // Adds another detail view by adding to the recursive structure of either views created
        // to display details in a type-safe manner. See NavigationStack.child for details.
        NavigationStack<EitherView<Detail, C>>(
            previous: self,
            destination: destination
        )
    }

    /// Add a destination for a specific path element (by adding another layer of ``EitherView``).
    private init<PreviousDetail: View, NewDetail: View, Component: Codable>(
        previous: NavigationStack<PreviousDetail>,
        destination: @escaping (Component) -> NewDetail?
    ) where Detail == EitherView<PreviousDetail, NewDetail> {
        _ownedPath = previous._ownedPath
        pathBinding = previous.pathBinding
        destinationTypes = previous.destinationTypes + [Component.self]
        child = {
            if let previous = previous.child($0) {
                // Either root or previously defined destination returned a view
                return EitherView(previous)
            } else if let component = $0 as? Component, let new = destination(component) {
                // This destination returned a detail view for the current element
                return EitherView(new)
            } else {
                // Possibly a future .navigationDestination will handle this path element
                return nil
            }
        }
    }

    /// Attempts to compute the detail view for the given element (the type of
    /// the element decides which detail is shown). Crashes if no suitable detail
    /// view is found.
<<<<<<< Updated upstream
    func childOrCrash(for element: some Codable) -> Detail {
=======
    fileprivate func childOrCrash(for element: any Codable) -> Detail {
>>>>>>> Stashed changes
        guard let child = child(element) else {
            fatalError(
                "Failed to find detail view for \"\(element)\", make sure you have called .navigationDestination for this type."
            )
        }

        return child
    }
<<<<<<< Updated upstream
=======

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> NavigationStackChildren<Detail> {
        NavigationStackChildren(
            from: self,
            backend: backend,
            snapshots: snapshots,
            environment: stackEnvironment(environment)
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: NavigationStackChildren<Detail>,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        let visibleIndex = children.visiblePageIndex ?? children.nodes.indices.last
        if let visibleIndex {
            let navBarIndex = 0
            let contentIndex = children.navigationBarNodes[visibleIndex] != nil ? 1 : 0
            if let navBarNode = children.navigationBarNodes[visibleIndex] {
                backend.insert(navBarNode.widget.into(), into: container, at: navBarIndex)
                backend.setPosition(ofChildAt: navBarIndex, in: container, to: .zero)
            }
            backend.insert(
                children.nodes[visibleIndex].widget.into(),
                into: container,
                at: contentIndex
            )
            backend.setPosition(
                ofChildAt: contentIndex,
                in: container,
                to: SIMD2(0, children.navBarHeights[visibleIndex])
            )
            children.visibleFallbackIndex = visibleIndex
        }
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: NavigationStackChildren<Detail>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let currentElements = elements
        synchronizeChildren(
            children,
            elements: currentElements,
            backend: backend,
            environment: environment
        )

        guard
            let currentIndex = children.nodes.indices.last,
            currentElements.indices.contains(currentIndex)
        else {
            return .leafView(size: .zero)
        }
        children.visiblePageIndex = currentIndex

        let navBarHeight: Int
        if let navBarNode = children.navigationBarNodes[currentIndex] {
            let navBarLayout = navBarNode.computeLayout(
                with: nil,
                proposedSize: ProposedViewSize(proposedSize.width, nil),
                environment: environment
            )
            navBarHeight = Int(navBarLayout.size.height)
            children.navBarHeights[currentIndex] = navBarHeight
        } else {
            navBarHeight = 0
        }

        let contentProposedSize = ProposedViewSize(
            proposedSize.width,
            proposedSize.height.map { max($0 - Double(navBarHeight), 0) }
        )

        let currentLayout = children.nodes[currentIndex].computeLayout(
            with: childOrCrash(for: currentElements[currentIndex]),
            proposedSize: contentProposedSize,
            environment: stackEnvironment(environment)
        )
        children.updatePageMetadata(at: currentIndex, from: currentLayout)

        let totalSize = ViewSize(
            currentLayout.size.width,
            currentLayout.size.height + Double(navBarHeight)
        )

        return ViewLayoutResult(
            size: totalSize,
            preferences: currentLayout.preferences
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: NavigationStackChildren<Detail>,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let visibleIndex = children.visiblePageIndex ?? children.nodes.indices.last

        if let visibleIndex = visibleIndex,
           let previousIndex = children.previousVisiblePageIndex,
           visibleIndex > previousIndex,
           children.pushAnimationOffset == nil {
            children.pushAnimationOffset = Double(layout.size.width)
            children.schedulePushAnimation(
                requestFrame: environment.requestRenderFrame,
                transaction: environment.transaction
            )
        }

        if children.visibleFallbackIndex != visibleIndex {
            backend.removeAllChildren(of: widget)
            if let visibleIndex = visibleIndex {
                let contentOffset = children.navBarHeights[visibleIndex]
                if let navBarNode = children.navigationBarNodes[visibleIndex] {
                    backend.insert(navBarNode.widget.into(), into: widget, at: 0)
                    backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
                }
                let contentIndex = children.navigationBarNodes[visibleIndex] != nil ? 1 : 0
                backend.insert(
                    children.nodes[visibleIndex].widget.into(),
                    into: widget,
                    at: contentIndex
                )
                backend.setPosition(
                    ofChildAt: contentIndex,
                    in: widget,
                    to: SIMD2(0, contentOffset)
                )
            }
            children.visibleFallbackIndex = visibleIndex
        }

        if let visibleIndex = visibleIndex {
            _ = children.navigationBarNodes[visibleIndex]?.commit()
            _ = children.nodes[visibleIndex].commit()

            let contentWidget = children.nodes[visibleIndex].widget.into() as Backend.Widget
            if let offset = children.pushAnimationOffset {
                backend.setTransform(of: contentWidget, to: .translation(x: offset, y: 0))
            } else {
                backend.setTransform(of: contentWidget, to: .identity)
            }
        }

        children.previousVisiblePageIndex = visibleIndex
        backend.setSize(of: widget, to: layout.size.vector)
    }

    func readObservationDependencies(in environment: EnvironmentValues) {
        let currentElements = elements
        guard let currentElement = currentElements.last else {
            return
        }

        let currentView = childOrCrash(for: currentElement)
        let environment = stackEnvironment(environment)
        if let trackedView = currentView as? any ObservationTrackingView {
            trackedView.readObservationDependencies(in: environment)
        } else {
            _ = currentView.body
        }
    }

    private func synchronizeChildren<Backend: BaseAppBackend>(
        _ children: NavigationStackChildren<Detail>,
        elements currentElements: [any Codable],
        backend: Backend,
        environment: EnvironmentValues
    ) {
        if children.nodes.count > currentElements.count {
            let diff = children.nodes.count - currentElements.count
            children.nodes.removeLast(diff)
            children.navigationTitles.removeLast(diff)
            children.toolbars.removeLast(diff)
            children.navigationBarNodes.removeLast(diff)
            children.navBarHeights.removeLast(diff)
        }

        if children.nodes.count < currentElements.count {
            for element in currentElements.dropFirst(children.nodes.count) {
                let index = children.nodes.count
                children.nodes.append(
                    AnyViewGraphNode(
                        for: childOrCrash(for: element),
                        backend: backend,
                        environment: stackEnvironment(environment)
                    )
                )
                children.navigationTitles.append(nil)
                children.toolbars.append(.empty)

                let navBar = NavigationBar(
                    title: nil,
                    onBack: index > 0 ? { [path = self.path] in
                        path.wrappedValue.removeLast()
                    } : nil
                )
                children.navigationBarNodes.append(
                    AnyViewGraphNode(
                        for: navBar,
                        backend: backend,
                        environment: environment
                    )
                )
                children.navBarHeights.append(0)
            }
        }

        for index in children.navigationBarNodes.indices {
            guard let navBarNode = children.navigationBarNodes[index] else {
                continue
            }
            let title = children.navigationTitles[index]
            let newNavBar = NavigationBar(
                title: title,
                onBack: index > 0 ? { [path = self.path] in
                    path.wrappedValue.removeLast()
                } : nil
            )
            _ = navBarNode.computeLayout(
                with: newNavBar,
                proposedSize: ProposedViewSize(nil, nil),
                environment: environment
            )
        }
    }

    private func stackEnvironment(_ environment: EnvironmentValues) -> EnvironmentValues {
        environment.with(\.navigationPathBinding, path)
    }
}

final class NavigationStackChildren<Detail: View>: ViewGraphNodeChildren {
    var nodes: [AnyViewGraphNode<Detail>]
    var navigationTitles: [String?]
    var toolbars: [ResolvedToolbar]
    var visiblePageIndex: Int?
    var visibleFallbackIndex: Int?
    var previousVisiblePageIndex: Int?
    var navigationBarNodes: [AnyViewGraphNode<NavigationBar>?]
    var navBarHeights: [Int]
    var pushAnimationOffset: Double?
    private var pushAnimationRequestFrame: (@MainActor (Transaction) -> Void)?
    private var pushAnimationTransaction: Transaction?
    private var pushAnimationScheduled = false

    var widgets: [AnyWidget] {
        nodes.map(\.widget) + navigationBarNodes.compactMap { $0?.widget }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        nodes.map(ErasedViewGraphNode.init(wrapping:))
            + navigationBarNodes.compactMap { $0.map(ErasedViewGraphNode.init(wrapping:)) }
    }

    init<Backend: BaseAppBackend>(
        from view: NavigationStack<Detail>,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        let snapshotCount = snapshots?.count ?? 0
        let path = view.path
        nodes = view.elements.enumerated().map { index, element in
            AnyViewGraphNode(
                for: view.childOrCrash(for: element),
                backend: backend,
                snapshot: index < snapshotCount ? snapshots?[index] : nil,
                environment: environment
            )
        }
        navigationTitles = Array(repeating: nil, count: nodes.count)
        toolbars = Array(repeating: .empty, count: nodes.count)
        visiblePageIndex = nodes.indices.last
        visibleFallbackIndex = nil
        previousVisiblePageIndex = nil

        navigationBarNodes = nodes.enumerated().map { index, _ in
            let navBar = NavigationBar(
                title: nil,
                onBack: index > 0 ? { path.wrappedValue.removeLast() } : nil
            )
            return AnyViewGraphNode(
                for: navBar,
                backend: backend,
                environment: environment
            )
        }
        navBarHeights = Array(repeating: 0, count: nodes.count)
        pushAnimationOffset = nil
    }

    func updatePageMetadata(at index: Int, from layout: ViewLayoutResult) {
        guard navigationTitles.indices.contains(index), toolbars.indices.contains(index) else {
            return
        }
        navigationTitles[index] = layout.preferences.navigationTitle
        toolbars[index] = layout.preferences.toolbar
    }

    func schedulePushAnimation(
        requestFrame: @MainActor @escaping (Transaction) -> Void,
        transaction: Transaction
    ) {
        guard !pushAnimationScheduled else { return }
        pushAnimationScheduled = true
        pushAnimationRequestFrame = requestFrame
        pushAnimationTransaction = transaction
        scheduleNextAnimationFrame()
    }

    private func scheduleNextAnimationFrame() {
        guard pushAnimationOffset != nil else {
            pushAnimationScheduled = false
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) { [weak self] in
            guard let self else { return }
            guard self.pushAnimationOffset != nil else {
                self.pushAnimationScheduled = false
                return
            }
            if let offset = self.pushAnimationOffset {
                let newOffset = offset * 0.85
                if newOffset < 1.0 {
                    self.pushAnimationOffset = nil
                } else {
                    self.pushAnimationOffset = newOffset
                }
            }
            if let requestFrame = self.pushAnimationRequestFrame,
               let transaction = self.pushAnimationTransaction {
                requestFrame(transaction)
            }
            if self.pushAnimationOffset != nil {
                self.scheduleNextAnimationFrame()
            } else {
                self.pushAnimationScheduled = false
            }
        }
    }
>>>>>>> Stashed changes
}
