/// A type that specifies the appearance and interaction of all pickers within a view hierarchy.
@MainActor
public protocol PickerStyle: Sendable {
    associatedtype Body: View

    /// The method used to render ``Picker``.
    /// - Parameters:
    ///   - options: The options that the picker should display.
    ///   - selection: A binding to the picker's currently selected value. May
    ///     hold nil if no value has been chosen.
    ///   - environment: The environment the picker is being rendered in.
    func makeView<Value: Equatable>(
        options: [Value],
        selection: Binding<Value?>,
        environment: EnvironmentValues
    ) -> Body

    /// The method used to render ``Picker`` when its options carry distinct
    /// display labels (from tagged picker content).
    /// - Parameters:
    ///   - labeledOptions: The options (value + optional label) to display.
    ///   - selection: A binding to the picker's currently selected value.
    ///   - environment: The environment the picker is being rendered in.
    func makeView<Value: Equatable>(
        labeledOptions: [PickerOption<Value>],
        selection: Binding<Value?>,
        environment: EnvironmentValues
    ) -> Body

    /// A method that can be used to check whether a picker style is currently
    /// supported by a specific backend.
    ///
    /// To determine whether a picker style is supported, use the environment
    /// action ``EnvironmentValues/isPickerStyleSupported`` instead. This method
    /// is used to implement that check.
    ///
    /// The default implementation always returns `true`.
    /// - Parameter backend: The backend being queried for support.
    func isSupported<Backend: BaseAppBackend>(backend: Backend) -> Bool
}

extension PickerStyle {
    public func isSupported<Backend: BaseAppBackend>(backend: Backend) -> Bool {
        // Custom picker styles are supported on all platforms by default.
        true
    }

    /// Default implementation ignoring option labels, for styles that render
    /// values directly.
    public func makeView<Value: Equatable>(
        labeledOptions: [PickerOption<Value>],
        selection: Binding<Value?>,
        environment: EnvironmentValues
    ) -> Body {
        makeView(
            options: labeledOptions.map(\.value),
            selection: selection,
            environment: environment
        )
    }
}
