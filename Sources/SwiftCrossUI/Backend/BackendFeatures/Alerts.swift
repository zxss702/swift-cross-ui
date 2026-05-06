extension BackendFeatures {
    /// Backend methods for alerts.
    ///
    /// These are used by ``View/alert(_:actions:)``,
    /// ``View/alert(_:isPresented:actions:)``, ``EnvironmentValues/presentAlert``,
    /// and ``AlertScene``.
    @MainActor
    public protocol Alerts<Alert>: Core {
        /// The underlying alert type. Can be a wrapper or subclass.
        associatedtype Alert

        /// Creates an alert object (without showing it).
        ///
        /// Alerts contain a title, an optional body, and a set of action buttons.
        /// They prevent users from interacting with the parent window until
        /// dimissed.
        ///
        /// - Returns: An alert.
        func createAlert() -> Alert

        /// Updates the content and appearance of an alert.
        ///
        /// Can only be called once.
        ///
        /// - Parameters:
        ///   - alert: The alert to update.
        ///   - title: The title of the alert.
        ///   - actionLabels: The labels of the alert's action buttons.
        ///   - environment: The current environment.
        func updateAlert(
            _ alert: Alert,
            title: String,
            actionLabels: [String],
            environment: EnvironmentValues
        )

        /// Shows an alert as a modal on top of or within the given surface.
        ///
        /// Users should be unable to interact with the parent surface until the
        /// alert is dismissed.
        ///
        /// Must only be called once for any given alert.
        ///
        /// - Parameters:
        ///   - alert: The alert to show.
        ///   - surface: The surface to attach the alert to. If `nil`, the backend can
        ///     either make the alert a whole app modal, a standalone surface, or a
        ///     modal for a surface of its choosing.
        ///   - handleResponse: The code to run when an action is selected. Receives
        ///     the index of the chosen action (as per the `actionLabels` array).
        ///     The alert will have already been hidden by the time this gets
        ///     called.
        func showAlert(
            _ alert: Alert,
            surface: Surface?,
            responseHandler handleResponse: @escaping (Int) -> Void
        )

        /// Dismisses an alert programmatically without invoking the response
        /// handler.
        ///
        /// Must only be called after ``showAlert(_:surface:responseHandler:)``.
        ///
        /// - Parameters:
        ///   - alert: The alert to dismiss.
        ///   - surface: The surface the alert is attached to, if any.
        func dismissAlert(_ alert: Alert, surface: Surface?)
    }
}
