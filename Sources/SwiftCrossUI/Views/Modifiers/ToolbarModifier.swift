/// A modifier that contributes toolbar items to the nearest native toolbar consumer.
struct ToolbarModifier<Child: View>: View {
    var body: TupleView1<Child>
    var content: @MainActor () -> [ToolbarItem]

    init(
        _ child: Child,
        @ToolbarContentBuilder content: @escaping @MainActor () -> [ToolbarItem]
    ) {
        self.body = TupleView1(child)
        self.content = content
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        var result = body.computeLayout(
            widget,
            children: children,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )

        let toolbar = ResolvedToolbar(
            items: content().flatMap { $0.resolve() }
        )
        result.preferences.toolbar = result.preferences.toolbar.overlayed(with: toolbar)
        return result
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
            environment: environment,
            backend: backend
        )
    }
}

extension View {
    /// Adds toolbar items to the nearest native toolbar consumer.
    public func toolbar(
        @ToolbarContentBuilder content: @escaping @MainActor () -> [ToolbarItem]
    ) -> some View {
        ToolbarModifier(self, content: content)
    }

    /// Sets the title used by the nearest native navigation container.
    public func navigationTitle(_ title: String) -> some View {
        preference(key: \.navigationTitle, value: title)
    }
}
