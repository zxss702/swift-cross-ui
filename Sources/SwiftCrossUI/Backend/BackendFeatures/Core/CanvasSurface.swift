extension BackendFeatures {
    /// Core backend methods for surface handling. These are required for a
    /// functional backend.
    @MainActor
    public protocol CanvasSurface<Surface>: Widgets {
        /// The underlying surface type. Can be a wrapper or subclass.
        associatedtype Surface

        /// Whether the backend can have multiple surfaces open at once. Mobile
        /// backends generally can't.
        var supportsMultipleWindows: Bool { get }

        /// Whether the backend supports overriding surface color schemes (as you may
        /// do with the ``View/preferredColorScheme(_:)`` modifier).
        ///
        /// If `false`, then SwiftCrossUI will ignore the `preferredColorScheme(_:)``
        /// modifier as a nicer failure mode.
        var canOverrideWindowColorScheme: Bool { get }

        /// Creates a new surface.
        ///
        /// For some backends it may make sense for this method to return the
        /// application's root surface the first time its called, and only create new
        /// surfaces on subsequent invocations.
        ///
        /// A surface's content size has precendence over the default size. The
        /// surface should always be at least the size of its content.
        ///
        /// - Parameter defaultSize: The default size of the surface. This is only a
        ///   suggestion; for example some backends may choose to restore the user's
        ///   preferred surface size from a previous session.
        /// - Returns: The created surface.
        func createSurface(withDefaultSize defaultSize: SIMD2<Int>?) -> Surface

        /// Updates a surface, generally to react to the current color scheme from the
        /// environment.
        ///
        /// - Parameters:
        ///   - surface: The surface to update.
        ///   - environment: the current environment.
        func updateSurface(_ surface: Surface, environment: EnvironmentValues)

        /// Sets the root child of a surface.
        ///
        /// This replaces the previous child if one exists.
        ///
        /// - Parameters:
        ///   - surface: The surface to set the root child of.
        ///   - child: The new root child.
        func setChild(ofSurface surface: Surface, to child: Widget)

        /// Gets the size of the given surface in pixels.
        ///
        /// - Parameter surface: The surface to get the size of.
        /// - Returns: The surface's size in pixels.
        func size(ofSurface surface: Surface) -> SIMD2<Int>

        /// Check whether a surface is programmatically resizable.
        ///
        /// This value does not necessarily reflect whether the surface is resizable
        /// by the user.
        ///
        /// - Parameter surface: The surface to check.
        /// - Returns: Whether the surface is programmatically resizable.
        func isSurfaceProgrammaticallyResizable(_ surface: Surface) -> Bool

        /// Sets the size (in pixels) of the given surface.
        ///
        /// - Parameters:
        ///   - surface: The surface to set the size of.
        ///   - newSize: The new size.
        func setSize(ofSurface surface: Surface, to newSize: SIMD2<Int>)

        /// Sets the minimum and maximum width and height of a surface.
        ///
        /// Prevents the user from making the surface any smaller or larger than the
        /// given minimum and maximum sizes, respectively.
        ///
        /// - Parameters:
        ///   - surface: The surface to set the size limits of.
        ///   - minimumSize: The minimum surface size.
        ///   - maximumSize: The maximum surface size. If `nil`, any existing maximum
        ///     size constraints should be removed.
        func setSizeLimits(
            ofSurface surface: Surface,
            minimum minimumSize: SIMD2<Int>,
            maximum maximumSize: SIMD2<Int>?
        )

        /// Sets the handler for the surface's resizing events.
        ///
        /// Setting the resize handler overrides any previous handler.
        ///
        /// - Parameters:
        ///   - surface: The surface to set the resize handler of.
        ///   - action: The new resize handler. Takes the surface's proposed size.
        func setResizeHandler(
            ofSurface surface: Surface,
            to action: @escaping (_ newSize: SIMD2<Int>) -> Void
        )

        /// Shows a surface after it has been created or updated (may be unnecessary
        /// for some backends).
        ///
        /// Predominantly used by window-based ``Scene`` implementations after
        /// propagating updates.
        ///
        /// - Parameter surface: The surface to show.
        func show(surface: Surface)

        /// Closes a surface.
        ///
        /// At some point during or after execution of this function, the handler
        /// set by ``setCloseHandler(ofSurface:to:)`` should be called.
        /// Oftentimes this will be done automatically by the backend's underlying
        /// UI framework.
        ///
        /// This is primarily used by ``DismissWindowAction``.
        func close(surface: Surface)

        /// Sets the handler for the surface's close events (for example, when the
        /// user clicks the close button in the title bar).
        ///
        /// The close handler should also be called whenever ``close(surface:)-9xucx``
        /// is called (some UI frameworks do this automatically).
        ///
        /// This is used by SwiftCrossUI to release scene nodes' references to
        /// `surface` when the surface is closed.
        ///
        /// This is only called once per surface; as such, it doesn't matter if
        /// setting the close handler again overrides the previous handler or adds a
        /// new one.
        func setCloseHandler(
            ofSurface surface: Surface,
            to action: @escaping () -> Void
        )

        /// Computes the environment for a surface.
        ///
        /// - Parameters:
        ///   - surface: The surface to compute the environment for.
        ///   - rootEnvironment: The root environment.
        /// - Returns: The computed environment for the surface.
        func computeSurfaceEnvironment(
            surface: Surface,
            rootEnvironment: EnvironmentValues
        ) -> EnvironmentValues

        /// Sets the handler to be notified when the surface's environment may need
        /// recomputation.
        ///
        /// - Parameters:
        ///   - surface: The surface to set the handler for.
        ///   - action: The environment change handler.
        func setSurfaceEnvironmentChangeHandler(
            of surface: Surface,
            to action: @escaping @Sendable @MainActor () -> Void
        )
    }
}

// MARK: Default implementations
public extension BackendFeatures.CanvasSurface {
    func computeSurfaceEnvironment(
        surface: Surface,
        rootEnvironment: EnvironmentValues
    ) -> EnvironmentValues {
        rootEnvironment
    }

    func setSurfaceEnvironmentChangeHandler(
        of surface: Surface,
        to action: @escaping @Sendable @MainActor () -> Void
    ) {
        // No-op by default
    }
}
