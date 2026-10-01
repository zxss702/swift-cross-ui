extension BackendFeatures {
    /// Backend methods for toggle buttons.
    ///
    /// These are used by ``Toggle`` when ``EnvironmentValues/toggleStyle`` is
    /// ``ToggleStyle/button``.
    @MainActor
    public protocol ToggleButtons: Core {
        /// Creates a labelled toggle that is either on or off.
        ///
        /// - Returns: A toggle.
        func createToggle() -> Widget

        /// Sets the label and change handler of a toggle.
        ///
        /// - Parameters:
        ///   - toggle: The toggle to update.
        ///   - label: The toggle's label.
        ///   - environment: The current environment.
        ///   - onChange: The action to perform when the button is toggled on or
        ///     off. This replaces any existing change handlers.
        func updateToggle(
            _ toggle: Widget,
            label: String,
            environment: EnvironmentValues,
            onChange: @escaping (Bool) -> Void
        )

        /// Sets the state of a toggle.
        ///
        /// - Parameters:
        ///   - toggle: The toggle to set the state of.
        ///   - state: The new state.
        func setState(ofToggle toggle: Widget, to state: Bool)
    }

    /// Backend methods for toggle buttons supporting an arbitrary ``View`` as
    /// label.
    ///
    /// These are used by ``Toggle`` when ``EnvironmentValues/toggleStyle`` is
    /// ``ToggleStyle/button`` and the toggle was created with a custom view
    /// label. Backends that don't implement this protocol get a plain
    /// ``Button`` fallback (which displays no checked state).
    @MainActor
    public protocol ViewLabelToggleButtons: ToggleButtons {
        /// Creates a toggle that uses `widget` as its label.
        ///
        /// - Parameters:
        ///   - widget: The widget the toggle should use as label.
        ///
        /// - Returns: A toggle.
        func createToggle(wrapping widget: Widget) -> Widget

        /// Sets the environment and change handler of a view-labelled toggle.
        ///
        /// - Parameters:
        ///   - toggle: The toggle to update.
        ///   - environment: The current environment.
        ///   - onChange: The action to perform when the button is toggled on
        ///     or off. This replaces any existing change handlers.
        func updateToggle(
            _ toggle: Widget,
            environment: EnvironmentValues,
            onChange: @escaping (Bool) -> Void
        )
    }
}
