/// A button style control that is either on or off.
///
/// This corresponds to the ``ToggleStyle/button`` toggle style.
struct ToggleButton: ElementaryView, View {
    /// The label to show on the toggle button.
    private var label: String
    /// Whether the button is active or not.
    private var active: Binding<Bool>

    /// Creates a toggle button that displays a custom label.
    ///
    /// - Parameters:
    ///   - label: The label to show on the toggle button.
    ///   - active: Whether the button is active or not.
    public init(_ label: String, isOn active: Binding<Bool>) {
        self.label = label
        self.active = active
    }

    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        return backend.createToggle()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        // TODO: Implement toggle button sizing within SwiftCrossUI so that we
        //   can delay updating the underlying widget until `commit`.
        backend.updateToggle(widget, label: label, environment: environment) { newActiveState in
            if active.wrappedValue != newActiveState {
                active.wrappedValue = newActiveState
            }
        }
        return ViewLayoutResult
            .leafView(size: ViewSize(backend.naturalSize(of: widget)))
            .with(\.isNeverFocusable, false)
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setState(ofToggle: widget, to: active.wrappedValue)
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

/// A button style control with a custom view label that is either on or off.
///
/// This corresponds to the ``ToggleStyle/button`` toggle style. On backends
/// implementing ``BackendFeatures/ViewLabelToggleButtons`` the label view is
/// hosted by a native toggle button (showing a checked state); other backends
/// fall back to a plain ``Button``.
struct ViewLabelledToggleButton: TypeSafeView {
    /// The view to use as the toggle button's label.
    var label: () -> AnyView
    /// Whether the button is active or not.
    var active: Binding<Bool>

    var body: TupleView1<AnyView> {
        TupleView1(label())
    }

    typealias Children = ViewLabelledToggleButtonStorage

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        let storage = ViewLabelledToggleButtonStorage()
        storage.labelChildren = TupleViewChildren1(
            label(),
            backend: backend,
            snapshots: snapshots,
            environment: environment
        )
        return storage
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        if let backend = backend as? any BaseAppBackend & BackendFeatures.ViewLabelToggleButtons {
            children.isNativeToggle = true
            return makeToggle(children: children, backend: backend) as! Backend.Widget
        }
        children.isNativeToggle = false
        return backend.createButton(wrapping: children.labelChildren!.child0.widget.into())
    }

    private func makeToggle<SubBackend: BaseAppBackend & BackendFeatures.ViewLabelToggleButtons>(
        children: Children,
        backend: SubBackend
    ) -> SubBackend.Widget {
        backend.createToggle(wrapping: children.labelChildren!.child0.widget.into())
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let labelChildren = children.labelChildren!
        let childEnvironment = backend.computeButtonLabelEnvironment(from: environment)

        if children.isNativeToggle {
            _ = labelChildren.child0.computeLayout(
                with: label(),
                proposedSize: proposedSize,
                environment: childEnvironment
            )
            updateToggle(widget, environment: environment, backend: backend) { newActiveState in
                if active.wrappedValue != newActiveState {
                    active.wrappedValue = newActiveState
                }
            }
            return ViewLayoutResult
                .leafView(size: ViewSize(backend.naturalSize(of: widget)))
                .with(\.isNeverFocusable, false)
        }

        // Plain button fallback: identical sizing to `Button.computeLayout`.
        let buttonPadding = backend.buttonPadding(in: environment)

        var childProposal = proposedSize
        if let proposedWidth = proposedSize.width {
            childProposal.width = max(proposedWidth - Double(buttonPadding.x), 0)
        }
        if let proposedHeight = proposedSize.height {
            childProposal.height = max(proposedHeight - Double(buttonPadding.y), 0)
        }

        let childResult = labelChildren.child0.computeLayout(
            with: label(),
            proposedSize: childProposal,
            environment: childEnvironment
        )

        backend.updateButton(widget, environment: environment) {
            active.wrappedValue.toggle()
        }

        let size = ViewSize(
            childResult.size.width + Double(buttonPadding.x),
            childResult.size.height + Double(buttonPadding.y)
        )

        return ViewLayoutResult
            .leafView(size: size)
            .with(\.isNeverFocusable, false)
    }

    private func updateToggle<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        environment: EnvironmentValues,
        backend: Backend,
        onChange: @escaping (Bool) -> Void
    ) {
        guard
            let backend = backend as? any BaseAppBackend & BackendFeatures.ViewLabelToggleButtons
        else { return }
        updateToggleOnBackend(widget, environment: environment, backend: backend, onChange: onChange)
    }

    private func updateToggleOnBackend<
        SubBackend: BaseAppBackend & BackendFeatures.ViewLabelToggleButtons
    >(
        _ widget: Any,
        environment: EnvironmentValues,
        backend: SubBackend,
        onChange: @escaping (Bool) -> Void
    ) {
        backend.updateToggle(
            widget as! SubBackend.Widget,
            environment: environment,
            onChange: onChange
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        if children.isNativeToggle {
            backend.setState(ofToggle: widget, to: active.wrappedValue)
        }
        _ = children.labelChildren!.child0.commit()
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

class ViewLabelledToggleButtonStorage: ViewGraphNodeChildren {
    var labelChildren: TupleViewChildren1<AnyView>?
    var isNativeToggle = false

    var widgets: [AnyWidget] {
        labelChildren?.widgets ?? []
    }
    var erasedNodes: [ErasedViewGraphNode] {
        labelChildren?.erasedNodes ?? []
    }

    init() {}
}
