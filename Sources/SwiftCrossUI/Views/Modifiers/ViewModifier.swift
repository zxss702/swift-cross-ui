/// A modifier that creates a new view from an existing view.
@MainActor
public protocol ViewModifier {
    associatedtype Body: View

    typealias Content = PlaceholderContentView<Self>

    @ViewBuilder func body(content: Content) -> Body
}

/// A view formed by applying a modifier to content.
public struct ModifiedContent<Content: View, Modifier: ViewModifier>: TypeSafeView {
    typealias Children = ModifiedContentChildren<Modifier.Body>

    public var content: Content
    public var modifier: Modifier
    public var body = EmptyView()

    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        Children(
            content: modifiedContent,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: Children,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.widget.into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.node.computeLayout(
            with: modifiedContent,
            proposedSize: proposedSize,
            environment: environment
        )
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: Children,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
    }

    private var modifiedContent: Modifier.Body {
        modifier.body(content: PlaceholderContentView(content))
    }
}

class ModifiedContentChildren<Content: View>: ViewGraphNodeChildren {
    var node: AnyViewGraphNode<Content>

    var widgets: [AnyWidget] {
        [node.widget]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [ErasedViewGraphNode(wrapping: node)]
    }

    init<Backend: AppBackend>(
        content: Content,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        node = AnyViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}

/// A placeholder for modifier and transition content.
public struct PlaceholderContentView<Source>: TypeSafeView {
    typealias Children = PlaceholderContentChildren

    public var body = EmptyView()
    private var content: any View

    init<V: View>(_ content: V) {
        self.content = content
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> PlaceholderContentChildren {
        PlaceholderContentChildren(
            content: content,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: PlaceholderContentChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.getWidget().into(), into: container, at: 0)
        backend.setPosition(ofChildAt: 0, in: container, to: .zero)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: PlaceholderContentChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let (_, result) = children.node.computeLayoutWithNewView(
            content,
            proposedSize,
            environment
        )
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: PlaceholderContentChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

class PlaceholderContentChildren: ViewGraphNodeChildren {
    var node: ErasedViewGraphNode

    var widgets: [AnyWidget] {
        [node.getWidget()]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node]
    }

    init<Backend: AppBackend>(
        content: any View,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        node = ErasedViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}

extension View {
    /// Applies a modifier to this view.
    public func modifier<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}
