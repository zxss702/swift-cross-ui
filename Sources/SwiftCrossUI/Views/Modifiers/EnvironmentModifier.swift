struct EnvironmentModifier<Child: View>: View {
    var body: TupleView1<Child>
    var modification: (EnvironmentValues) -> EnvironmentValues

    init(_ child: Child, modification: @escaping (EnvironmentValues) -> EnvironmentValues) {
        self.body = TupleView1(child)
        self.modification = modification
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        body.children(
            backend: backend,
            snapshots: snapshots,
            environment: modification(environment)
        )
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: modification(environment),
            backend: backend
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: modification(environment),
            backend: backend
        )
    }

    public var _asMenuItems: [MenuItem] {
        self.body._asMenuItems.map { menuItem in
            .modifiedEnvironment({ menuItem }, { self.modification })
        }
    }
}

extension View {
    /// Modifies the environment of the View its applied to
    public func environment<T>(_ keyPath: WritableKeyPath<EnvironmentValues, T>, _ newValue: T)
        -> some View
    {
        EnvironmentModifier(self) { environment in
            environment.with(keyPath, newValue)
        }
    }

    /// Adds an observable object to the environment of the enclosed View.
    /// You are responsible for ensuring that the object is being observed
    /// by a parent view, as this modifier does not perform any observation.
    public func environment<T: AnyObject>(_ object: T) -> some View {
        EnvironmentModifier(self) { environment in
            var environment = environment
            environment[observable: T.self] = object
            return environment
        }
    }

    /// Adds an observable object to the environment of the enclosed View.
    /// You are responsible for ensuring that the object is being observed
    /// by a parent view, as this modifier does not perform any observation.
    @available(*, deprecated, renamed: "environment", message: "Use `environment(_:)` instead.")
    public func environmentObject<T: AnyObject>(_ object: T) -> some View {
        environment(object)
    }
}

/// A view that modifies the environment passed to its content. Containers
/// such as ``SplitView`` use this to inspect environment values (like
/// ``EnvironmentValues/navigationSplitViewColumnWidth``) applied directly to
/// their children, which would otherwise be invisible to the parent.
protocol EnvironmentModifyingView {
    /// Applies this view's environment modification.
    func modifyEnvironment(_ environment: EnvironmentValues) -> EnvironmentValues
    /// The content that the modification applies to.
    var environmentModifiedContent: any View { get }
}

extension EnvironmentModifier: EnvironmentModifyingView {
    func modifyEnvironment(_ environment: EnvironmentValues) -> EnvironmentValues {
        modification(environment)
    }

    var environmentModifiedContent: any View {
        body.view0
    }
}

extension EnvironmentValues {
    /// Returns the environment that a view's outer chain of
    /// ``EnvironmentModifier``s produces when applied to this environment.
    /// Stops at the first non-environment-modifying wrapper.
    func applyingModifiers(of view: any View) -> EnvironmentValues {
        var environment = self
        var current = view
        while true {
            if let modifier = current as? EnvironmentModifyingView {
                environment = modifier.modifyEnvironment(environment)
                current = modifier.environmentModifiedContent
            } else if let wrapper = current as? TransparentWrappingView {
                current = wrapper.wrappedContent
            } else {
                break
            }
        }
        return environment
    }
}
