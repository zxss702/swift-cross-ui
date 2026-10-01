extension BackendFeatures {
    /// Backend methods for popovers (anchored, light-dismissible flyouts).
    ///
    /// These are used by
    /// ``View/popover(isPresented:attachmentAnchor:arrowEdge:content:)``.
    /// On backends that don't implement this protocol, popovers fall back to
    /// sheet presentation.
    @MainActor
    public protocol Popovers<Popover>: Core {
        /// The underlying popover type. Can be a wrapper or subclass.
        associatedtype Popover: AnyObject

        /// Creates a popover object (without showing it).
        ///
        /// - Parameter content: The content of the popover.
        /// - Returns: A popover containing `content`.
        func createPopover(content: Widget) -> Popover

        /// Updates the content, appearance and behaviour of a popover.
        ///
        /// - Parameters:
        ///   - popover: The popover to update.
        ///   - content: The popover's current content widget. The same widget
        ///     that the popover was created with (re-set here so backends whose
        ///     popover type doesn't retain it can reattach it).
        ///   - environment: The environment that the popover is presented in.
        ///   - onDismiss: An action to perform when the popover gets dismissed
        ///     by the user (e.g. via light-dismiss). Not triggered by
        ///     programmatic dismissal through ``dismissPopover(_:)``.
        func updatePopover(
            _ popover: Popover,
            content: Widget,
            environment: EnvironmentValues,
            onDismiss: @escaping () -> Void
        )

        /// Presents a popover anchored to the given widget.
        ///
        /// This method must only be called once for any given popover.
        ///
        /// - Parameters:
        ///   - popover: The popover to present.
        ///   - widget: The widget to anchor the popover to.
        ///   - arrowEdge: The edge of the popover that its arrow sits on (the
        ///     popover appears on the opposite side of the anchor). If `nil`,
        ///     the platform's default placement should be used.
        func presentPopover(
            _ popover: Popover,
            relativeTo widget: Widget,
            arrowEdge: Edge?
        )

        /// Dismisses a popover programmatically.
        ///
        /// - Parameter popover: The popover to dismiss.
        func dismissPopover(_ popover: Popover)
    }
}
