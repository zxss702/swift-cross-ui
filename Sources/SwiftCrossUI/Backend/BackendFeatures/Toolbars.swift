extension BackendFeatures {
    /// Backend methods for native window toolbars.
    @MainActor
    public protocol WindowToolbars<Window>: Core {
        /// Sets the toolbar shown by a window.
        ///
        /// Backends may ignore placements that have no native equivalent.
        ///
        /// - Parameters:
        ///   - window: The window whose toolbar should be updated.
        ///   - toolbar: The resolved toolbar content.
        ///   - navigationTitle: The title contributed by the window's content.
        ///   - environment: The current environment.
        func setToolbar(
            ofWindow window: Window,
            to toolbar: ResolvedToolbar,
            navigationTitle: String?,
            environment: EnvironmentValues
        )
    }
}
