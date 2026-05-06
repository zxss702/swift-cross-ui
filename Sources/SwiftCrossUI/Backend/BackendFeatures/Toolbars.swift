extension BackendFeatures {
    /// Backend methods for native surface toolbars.
    @MainActor
    public protocol WindowToolbars<Surface>: Core {
        /// Sets the toolbar shown by a surface.
        ///
        /// Backends may ignore placements that have no native equivalent.
        ///
        /// - Parameters:
        ///   - surface: The surface whose toolbar should be updated.
        ///   - toolbar: The resolved toolbar content.
        ///   - navigationTitle: The title contributed by the surface's content.
        ///   - environment: The current environment.
        func setToolbar(
            ofSurface surface: Surface,
            to toolbar: ResolvedToolbar,
            navigationTitle: String?,
            environment: EnvironmentValues
        )
    }
}
