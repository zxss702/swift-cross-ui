/// A control for selecting from a set of values.
public struct Picker<Value: Equatable>: TypeSafeView {
    typealias Children = AnyViewChildren

    /// The options to be offered by the picker.
    private var options: [Value]
    /// A binding to the picker's selected option.
    private var value: Binding<Value?>

    @Environment(\.self) var environment

    /// Creates a new picker with the given options and a binding for the
    /// selected value.
    ///
    /// - Parameters:
    ///   - options: The options to be offered by the picker.
    ///   - value: A binding to the picker's selected option.
    public init(of options: [Value], selection value: Binding<Value?>) {
        self.options = options
        self.value = value
    }

    public var body: AnyView {
        return AnyView(
            environment.pickerStyle.makeView(
                options: options,
                selection: value,
                environment: environment
            )
        )
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> AnyViewChildren {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    func layoutableChildren<Backend: AppBackend>(
        backend: Backend,
        children: AnyViewChildren
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children)
    }

    func asWidget<Backend: AppBackend>(
        _ children: AnyViewChildren,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children, backend: backend)
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: AnyViewChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: AnyViewChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}
