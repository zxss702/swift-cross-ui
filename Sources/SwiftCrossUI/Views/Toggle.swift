/// A control for toggling between two values (usually representing on and off).
///
/// Depending on the value of ``EnvironmentValues/toggleStyle``, this control
/// can appear as a switch, a button, or a checkbox.
public struct Toggle: View {
    @Environment(\.toggleStyle) var toggleStyle

    /// The label to be shown on or beside the toggle.
    var label: String
    /// A view label to be shown instead of `label`, if provided.
    var labelView: (() -> AnyView)?
    /// Whether the toggle is active or not.
    var active: Binding<Bool>

    @available(*, deprecated, renamed: "init(_:isOn:)")
    public init(_ label: String, active: Binding<Bool>) {
        self.init(label, isOn: active)
    }

    /// Creates a toggle that displays a custom label.
    ///
    /// - Parameters:
    ///   - label: The label to be shown on or beside the toggle.
    ///   - active: Whether the toggle is active or not.
    public init(_ label: String, isOn active: Binding<Bool>) {
        self.label = label
        self.labelView = nil
        self.active = active
    }

    /// Creates a toggle that displays a custom view label.
    ///
    /// - Parameters:
    ///   - isOn: Whether the toggle is active or not.
    ///   - label: The view to be shown on or beside the toggle.
    public init<Label: View>(
        isOn active: Binding<Bool>,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.label = ""
        self.labelView = { AnyView(label()) }
        self.active = active
    }

    public var body: some View {
        switch toggleStyle.style {
            case .switch:
                HStack {
                    if let labelView {
                        labelView()
                    } else {
                        Text(label)
                    }

                    HorizontalControlSpacer()

                    ToggleSwitch(isOn: active)
                }
            case .button:
                if let labelView {
                    Button(
                        action: { active.wrappedValue.toggle() },
                        label: { labelView() }
                    )
                } else {
                    ToggleButton(label, isOn: active)
                }
            case .checkbox:
                HStack {
                    if let labelView {
                        labelView()
                    } else {
                        Text(label)
                    }

                    HorizontalControlSpacer()

                    Checkbox(isOn: active)
                }
        }
    }

    public var _asMenuItems: [MenuItem] {
        [.toggle(self)]
    }
}

/// A style of toggle.
public struct ToggleStyle: Sendable {
    @_spi(Backends) public var style: Style

    /// A toggle switch.
    public static let `switch` = Self(style: .switch)
    /// A toggle button. Generally looks like a regular button when off and an
    /// accented button when on.
    public static let button = Self(style: .button)
    /// A checkbox.
    public static let checkbox = Self(style: .checkbox)

    @_spi(Backends) public enum Style: Sendable {
        case `switch`
        case button
        case checkbox
    }
}
