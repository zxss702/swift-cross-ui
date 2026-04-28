/// The content passed to a ``ViewModifier``.
public struct ViewModifierContent: View {
    public var body: AnyView

    init<Content: View>(_ content: Content) {
        body = AnyView(content)
    }

    public func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> any ViewGraphNodeChildren {
        body.children(backend: backend, snapshots: snapshots, environment: environment)
    }

    public func layoutableChildren<Backend: AppBackend>(
        backend: Backend,
        children: any ViewGraphNodeChildren
    ) -> [LayoutSystem.LayoutableChild] {
        body.layoutableChildren(backend: backend, children: children as! AnyViewChildren)
    }

    public func asWidget<Backend: AppBackend>(
        _ children: any ViewGraphNodeChildren,
        backend: Backend
    ) -> Backend.Widget {
        body.asWidget(children as! AnyViewChildren, backend: backend)
    }

    public func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        body.computeLayout(
            widget,
            children: children as! AnyViewChildren,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )
    }

    public func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        body.commit(
            widget,
            children: children as! AnyViewChildren,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }
}

/// A modifier that produces a new view from existing content.
///
/// This mirrors SwiftUI's mental model closely enough for modifiers to be
/// reusable from regular view code and transition definitions.
@MainActor
public protocol ViewModifier: Animatable {
    associatedtype Body: View
    typealias Content = ViewModifierContent

    @ViewBuilder func body(content: Content) -> Body
}

public struct ModifiedContent<Content: View, Modifier: ViewModifier>: View {
    public var content: Content
    public var modifier: Modifier

    public var body: some View {
        modifier.body(content: ViewModifierContent(content))
    }
}

extension View {
    public func modifier<Modifier: ViewModifier>(
        _ modifier: Modifier
    ) -> ModifiedContent<Self, Modifier> {
        ModifiedContent(content: self, modifier: modifier)
    }
}
