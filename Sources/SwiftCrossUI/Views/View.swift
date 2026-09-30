/// A view that can be rendered by any backend.
@MainActor
public protocol View {
    /// The view's content (composed of other views).
    associatedtype Content: View

    /// The view's contents.
    @ViewBuilder var body: Content { get }

    /// Gets the view's children as a type-erased collection of view graph
    /// nodes.
    ///
    /// The collection is type-erased to avoid leaking complex requirements to
    /// users implementing their own regular views.
    ///
    /// - Parameters:
    ///   - backend: The app's backend.
    ///   - snapshots: A list of snapshots, used to restore view state during a
    ///     hot reload.
    ///   - environment: The current environment.
    /// - Returns: The view's children as a type-erased collection of view graph
    ///   nodes.
    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren

    // TODO: Perhaps this can be split off into a separate protocol for the `TupleViewN`s
    //   if we can set up the generics right for VStack.
    /// Gets the view's children in a format that can be consumed by the
    /// ``LayoutSystem``.
    ///
    /// This really only needs to be its own method for views such as ``VStack``
    /// which treat their child's children as their own and skip over their
    /// direct child. Only needs to be implemented by the `TupleViewN`s.
    ///
    /// - Parameters:
    ///   - backend: The app's backend.
    ///   - children: The view's children.
    /// - Returns: The view's children in a format that can be consumed by the
    /// ``LayoutSystem``.
    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild]

    /// Creates the view's widget using the supplied backend.
    ///
    /// A view is represented by the same widget instance for the whole time
    /// that it's visible even if its content is changing; keep that in mind
    /// while deciding the structure of the widget. For example, a view
    /// displaying one of two children should use ``BackendFeatures/GenericContainers/createContainer()``
    /// to create a container for the displayed child instead of just directly
    /// returning the widget of the currently displayed child (which would
    /// result in you not being able to ever switch to displaying the other
    /// child). This constraint significantly simplifies view implementations
    /// without requiring widgets to be re-created after every single update.
    ///
    /// - Parameters:
    ///   - children: The view's children.
    ///   - backend: The app's backend.
    /// - Returns: The view's widget created using the given backend.
    func asWidget<Backend: BaseAppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget

    /// Computes this view's layout after a state change or a change in
    /// available space.
    ///
    /// This method should _not_ apply the layout to `widget`; that should be
    /// done in ``commit(_:children:layout:environment:backend:)`` instead.
    ///
    /// `proposedSize` is the size suggested by the parent container, but child
    /// views always get the final call on their own size.
    ///
    /// - Parameters:
    ///   - widget: The view's underlying widget.
    ///   - children: The view's children.
    ///   - proposedSize: The size suggested to the view by its parent
    ///     container.
    ///   - environment: The current environment.
    ///   - backend: The app's backend.
    /// - Returns: The view's computed size, along with any propagated
    ///   preferences.
    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult

    /// Commits the last computed layout to the underlying widget hierarchy.
    ///
    /// - Parameters:
    ///   - widget: The view's underlying widget.
    ///   - children: The view's children.
    ///   - layout: The layout to use for the view. Guaranteed to be the
    ///     last value returned by
    ///     ``computeLayout(_:children:proposedSize:environment:backend:)``.
    ///   - environment: The current environment.
    ///   - backend: The app's backend.
    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    )

    /// Returns this view as an array of ``MenuItem``s.
    ///
    /// The default implementation forwards to ``body``; you should never have to override this.
    ///
    /// - Warning: This is an implementation detail and is subject to be changed or removed at any
    ///   time.
    var _asMenuItems: [MenuItem] { get }
}

extension View {
    public func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        defaultChildren(
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
    }

    /// The default `View.children` implementation. Haters may see this as a
    /// composition lover re-implementing inheritance; I see it as innovation.
    public func defaultChildren<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        if body is any TupleView || Content.self == EmptyView.self {
            // Tuple views and empty views never require a backend widget of
            // their own, so flattening them into this node's children is safe.
            return body.children(
                backend: backend,
                snapshots: snapshots,
                environment: environment
            )
        } else {
            // Give `body` its own view graph node so that views with
            // specialised backend widgets (such as `ScrollView`, `SplitView`,
            // and `Shape`) actually get their real widget. Flattening them
            // would feed this node's plain container to their layout and
            // commit code, which generally assumes a specific widget type.
            return TupleViewChildren1(
                body,
                backend: backend,
                snapshots: snapshots,
                environment: environment
            )
        }
    }

    /// A `children` implementation for stack-like containers (such as
    /// ``VStack``/``HStack``/``ZStack``/``Group``). Wraps single non-tuple
    /// content in a view graph node so that modifiers and conditional content
    /// used as a stack's entire content keep their own widget and layout
    /// behaviour (they'd otherwise be flattened into the stack's children and
    /// skipped entirely, e.g. `VStack { Text("x").padding() }`).
    func stackChildren<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        if body is any TupleView || Content.self == EmptyView.self {
            return defaultChildren(
                backend: backend,
                snapshots: snapshots,
                environment: environment
            )
        } else {
            return TupleViewChildren1(
                body,
                backend: backend,
                snapshots: snapshots,
                environment: environment
            )
        }
    }

    /// A `layoutableChildren` implementation for stack-like containers;
    /// counterpart to ``stackChildren``.
    func stackLayoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        if let children = children as? TupleViewChildren1<Content> {
            return [
                LayoutSystem.LayoutableChild(
                    computeLayout: { proposedSize, environment in
                        children.child0.computeLayout(
                            with: body,
                            proposedSize: proposedSize,
                            environment: environment
                        )
                    },
                    commit: { children.child0.commit() },
                    tag: "\(Content.self)"
                )
            ]
        }
        return body.layoutableChildren(backend: backend, children: children)
    }

    public func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        defaultLayoutableChildren(backend: backend, children: children)
    }

    /// The default `View.layoutableChildren` implementation. Haters may see
    /// this as a composition lover re-implementing inheritance; I see it as
    /// innovation.
    public func defaultLayoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        stackLayoutableChildren(backend: backend, children: children)
    }

    public func asWidget<Backend: BaseAppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        defaultAsWidget(children, backend: backend)
    }

    /// The default `View.asWidget` implementation. Haters may see this as a
    /// composition lover re-implementing inheritance; I see it as innovation.
    public func defaultAsWidget<Backend: BaseAppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        if let children = children as? TupleViewChildren1<Content> {
            // `body` got its own node; wrap its widget in a plain container.
            let container = backend.createContainer()
            backend.insert(children.child0.widget.into(), into: container, at: 0)
            return container
        }
        let vStack = VStack(content: body)
        return vStack.asWidget(children, backend: backend)
    }

    public func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        defaultComputeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    /// The default `View.computeLayout` implementation. Haters may see this as a
    /// composition lover re-implementing inheritance; I see it as innovation.
    public func defaultComputeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        if let children = children as? TupleViewChildren1<Content> {
            // `body` is a node of its own; defer to it entirely so that the
            // node's own widget (not this container) gets laid out.
            return children.child0.computeLayout(
                with: body,
                proposedSize: proposedSize,
                environment: environment
            )
        }
        return body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        defaultCommit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }

    public func defaultCommit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        if let children = children as? TupleViewChildren1<Content> {
            _ = children.child0.commit()
            backend.setSize(of: widget, to: layout.size.vector)
            backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
            return
        }
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }

    public var _asMenuItems: [MenuItem] { body._asMenuItems }

    /// Resolves this view's menu content to the representation used by backends.
    ///
    /// This is the same resolution applied to ``Menu`` content and scene ``Commands``.
    /// - Returns: The resolved menu.
    @MainActor
    @_spi(Backends) public func resolvedMenuContent() -> ResolvedMenu {
        Menu.resolve(items: _asMenuItems)
    }
}
