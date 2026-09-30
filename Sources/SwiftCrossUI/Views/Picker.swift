/// A control for selecting from a set of values.
public struct Picker<Value: Equatable>: View {
    /// The options to be offered by the picker.
    private var options: [PickerOption<Value>]
    /// A binding to the picker's selected option.
    private var value: Binding<Value?>

    @Environment(\.self) var environment

    /// Creates a new picker with the given options and a binding for the
    /// selected value.
    ///
    /// - Parameters:
    ///   - options: The options to be offered by the picker.
    ///   - value: A binding to the picker's selected option.
    public init(of options: [Value], selection value: Binding<Value?>) {
        self.options = options.map { PickerOption(value: $0) }
        self.value = value
    }

    /// Creates a new picker with labeled options.
    init(of options: [PickerOption<Value>], selection value: Binding<Value?>) {
        self.options = options
        self.value = value
    }

    public var body: some View {
        AnyView(
            environment.pickerStyle.makeView(
                labeledOptions: options,
                selection: value,
                environment: environment
            )
        )
    }
}
