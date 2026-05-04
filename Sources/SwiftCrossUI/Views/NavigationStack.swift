/// Type to indicate the root of the NavigationStack. This is internal to prevent root accidentally showing instead
/// of a detail view.
struct NavigationStackRootPath: Codable {}

/// A view that displays a root view and enables you to present additional views
/// over the root view.
///
/// Use ``navigationDestination(for:destination:)`` on this view instead of its
/// children, unlike Apple's SwiftUI API.
public struct NavigationStack<Detail: View>: TypeSafeView, View {
    typealias Children = NavigationStackChildren<Detail>

    public var body = EmptyView()

    /// A binding to the current navigation path.
    var path: Binding<NavigationPath>
    /// The types handled by each destination (in the same order as their
    /// corresponding views in the stack).
    var destinationTypes: [any Codable.Type]
    /// Gets a recursive ``EitherView`` structure which will have a single view
    /// visible suitable for displaying the given path element (based on its
    /// type).
    ///
    /// It's implemented as a recursive structure because that's the best way to keep this
    /// typesafe without introducing some crazy generated pseudo-variadic storage types of
    /// some sort. This way we can easily have unlimited navigation destinations and there's
    /// just a single simple method for adding a navigation destination.
    var child: (any Codable) -> Detail?
    /// The elements of the navigation path. The result can depend on
    /// ``NavigationStack/destinationTypes`` which determines how the keys are
    /// decoded if they haven't yet been decoded (this happens if they're loaded
    /// from disk for persistence).
    var elements: [any Codable] {
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
        self.path = path
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
    ) -> NavigationStack<EitherView<Detail, C>> {
        // Adds another detail view by adding to the recursive structure of either views created
        // to display details in a type-safe manner. See NavigationStack.child for details.
        return NavigationStack<EitherView<Detail, C>>(
            previous: self,
            destination: destination
        )
    }

    /// Add a destination for a specific path element (by adding another layer of ``EitherView``).
    private init<PreviousDetail: View, NewDetail: View, Component: Codable>(
        previous: NavigationStack<PreviousDetail>,
        destination: @escaping (Component) -> NewDetail?
    ) where Detail == EitherView<PreviousDetail, NewDetail> {
        path = previous.path
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
    func childOrCrash(for element: any Codable) -> Detail {
        guard let child = child(element) else {
            fatalError(
                "Failed to find detail view for \"\(element)\", make sure you have called .navigationDestination for this type."
            )
        }

        return child
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> NavigationStackChildren<Detail> {
        NavigationStackChildren(
            from: self,
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: NavigationStackChildren<Detail>,
        backend: Backend
    ) -> Backend.Widget {
        if let nativeBackend = backend as? any BackendFeatures.NavigationStacks {
            func createStack<NewBackend: BackendFeatures.NavigationStacks>(
                backend: NewBackend
            ) -> Backend.Widget {
                backend.createNavigationStack() as! Backend.Widget
            }

            return createStack(backend: nativeBackend)
        } else {
            let container = backend.createContainer()
            if let widget = children.nodes.last?.widget {
                backend.insert(widget.into(), into: container, at: 0)
                backend.setPosition(ofChildAt: 0, in: container, to: .zero)
                children.visibleFallbackIndex = children.nodes.count - 1
            }
            return container
        }
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

        children.pageLayouts = zip(children.nodes, currentElements).map { node, element in
            node.computeLayout(
                with: childOrCrash(for: element),
                proposedSize: proposedSize,
                environment: environment
            )
        }

        guard let currentLayout = children.pageLayouts.last else {
            return .leafView(size: .zero)
        }

        return ViewLayoutResult(
            size: currentLayout.size,
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
        if let nativeBackend = backend as? any BackendFeatures.NavigationStacks {
            func setPages<NewBackend: BackendFeatures.NavigationStacks>(backend: NewBackend) {
                let pages: [NavigationStackPage<NewBackend.Widget>] = zip(
                    children.nodes, children.pageLayouts
                ).map { node, layout in
                    NavigationStackPage<NewBackend.Widget>(
                        widget: node.widget.into(),
                        navigationTitle: layout.preferences.navigationTitle,
                        toolbar: layout.preferences.toolbar
                    )
                }

                backend.setNavigationStackPages(
                    of: widget as! NewBackend.Widget,
                    to: pages,
                    environment: environment
                ) { pageIndex in
                    let targetPathCount = max(0, pageIndex)
                    let currentPathCount = path.wrappedValue.count
                    if targetPathCount < currentPathCount {
                        path.wrappedValue.removeLast(currentPathCount - targetPathCount)
                    }
                }
            }

            setPages(backend: nativeBackend)
            for node in children.nodes {
                _ = node.commit()
            }
        } else {
            let visibleIndex = children.nodes.indices.last
            if children.visibleFallbackIndex != visibleIndex {
                backend.removeAllChildren(of: widget)
                if let visibleIndex {
                    backend.insert(children.nodes[visibleIndex].widget.into(), into: widget, at: 0)
                    backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
                }
                children.visibleFallbackIndex = visibleIndex
            }

            if let visibleIndex {
                _ = children.nodes[visibleIndex].commit()
            }
        }

        backend.setSize(of: widget, to: layout.size.vector)
    }

    private func synchronizeChildren<Backend: BaseAppBackend>(
        _ children: NavigationStackChildren<Detail>,
        elements currentElements: [any Codable],
        backend: Backend,
        environment: EnvironmentValues
    ) {
        if children.nodes.count > currentElements.count {
            children.nodes.removeLast(children.nodes.count - currentElements.count)
        }

        if children.nodes.count < currentElements.count {
            for element in currentElements.dropFirst(children.nodes.count) {
                children.nodes.append(
                    AnyViewGraphNode(
                        for: childOrCrash(for: element),
                        backend: backend,
                        environment: environment
                    )
                )
            }
        }
    }
}

class NavigationStackChildren<Detail: View>: ViewGraphNodeChildren {
    var nodes: [AnyViewGraphNode<Detail>]
    var pageLayouts: [ViewLayoutResult]
    var visibleFallbackIndex: Int?

    var widgets: [AnyWidget] {
        nodes.map(\.widget)
    }

    var erasedNodes: [ErasedViewGraphNode] {
        nodes.map(ErasedViewGraphNode.init(wrapping:))
    }

    init<Backend: BaseAppBackend>(
        from view: NavigationStack<Detail>,
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) {
        nodes = view.elements.enumerated().map { index, element in
            AnyViewGraphNode(
                for: view.childOrCrash(for: element),
                backend: backend,
                snapshot: index < snapshots?.count ?? 0 ? snapshots?[index] : nil,
                environment: environment
            )
        }
        pageLayouts = []
        visibleFallbackIndex = nil
    }
}
