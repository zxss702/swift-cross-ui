extension BackendFeatures {
    /// Backend methods for context menus (right-click menus).
    ///
    /// Used by ``View/contextMenu(menuItems:)``. The shared view-graph layer
    /// applies ``EnvironmentValues/contextMenuItems`` to each committed
    /// widget via this protocol. Backends that don't implement it leave
    /// context menus inert.
    @MainActor
    public protocol ContextMenus: Core {
        /// Sets the menu shown when the widget is right-clicked or
        /// long-pressed.
        ///
        /// - Parameters:
        ///   - widget: The widget to attach the context menu to.
        ///   - items: The resolved menu items, or `nil` to remove the menu.
        ///   - environment: The environment the items were resolved in.
        func setContextMenu(
            on widget: Widget,
            items: ResolvedMenu?,
            environment: EnvironmentValues
        )
    }
}
