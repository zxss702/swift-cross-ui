@MainActor
enum BackendHelpers {
    /// Updates the focus properties of a widget.
    static func updateWidgetFocusProperties<Backend: BackendFeatures.FocusHandling>(
        of widget: AnyWidget,
        with backend: Backend,
        environment: EnvironmentValues
    ) {
        backend.registerFocusObservers(
            environment.widgetFocusObservers,
            on: widget.into()
        )

        backend.setFocusEffectDisabled(
            on: widget.into(),
            disabled: environment.focusEffectDisabled
        )
    }

    /// Makes a widget gain or lose focus.
    /// Can also leave the widget's focus unchanged if `nil`.
    static func setFocus<Backend: BackendFeatures.FocusHandling>(
        of widget: AnyWidget,
        to focus: Focus?,
        with backend: Backend
    ) {
        guard let focus else { return }
        backend.setFocus(of: widget.into(), to: focus)
    }

    /// Applies all environment dictated focus property changes to a widget
    /// and warns if the backend doesn't support focus handling.
    static func applyFocusRelatedProperties<Backend: BaseAppBackend>(
        from environment: EnvironmentValues,
        to widget: AnyWidget,
        with backend: Backend
    ) {
        if let backend2 = backend as? any BackendFeatures.FocusHandling {
            BackendHelpers.updateWidgetFocusProperties(
                of: widget,
                with: backend2,
                environment: environment
            )
            BackendHelpers.setFocus(
                of: widget,
                to: environment.focusOverride,
                with: backend2
            )
        } else if
            !environment.widgetFocusObservers.isEmpty ||
            environment.focusEffectDisabled ||
            environment.focusOverride != nil
        {
            logger.warnOnce("\(Backend.self) doesn't support focus control/tracking.")
        }
    }

    /// Applies ``EnvironmentValues/contextMenuItems`` to a widget. The
    /// context menu is re-resolved and re-applied on each update; backends
    /// are expected to avoid redundant work when items are unchanged.
    static func applyContextMenu<Backend: BaseAppBackend>(
        from environment: EnvironmentValues,
        to widget: AnyWidget,
        with backend: Backend
    ) {
        guard let menuBackend = backend as? any BackendFeatures.ContextMenus else {
            if environment.contextMenuItems != nil {
                logger.warnOnce("\(Backend.self) doesn't support context menus.")
            }
            return
        }
        applyContextMenu(from: environment, to: widget, with: menuBackend)
    }

    /// Re-binds ``BackendFeatures/ContextMenus``'s associated widget type so
    /// that it can be used through a protocol existential.
    private static func applyContextMenu<MenuBackend: BackendFeatures.ContextMenus>(
        from environment: EnvironmentValues,
        to widget: AnyWidget,
        with backend: MenuBackend
    ) {
        backend.setContextMenu(
            on: widget.into(),
            items: environment.contextMenuItems.map { Menu.resolve(items: $0) },
            environment: environment
        )
    }
}
