@_spi(Backends) import SwiftCrossUI
import UWP
import WinUI

// Many force tries are required for the WinUI backend but we don't really want them
// anywhere else so just disable the lint rule at a file level.
// swiftlint:disable force_try

// MARK: TextField

extension WinUIBackend {
    public func createTextField() -> Widget {
        let textField = TextBox()
        textField.textChanged.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.textFieldChangeActions[ObjectIdentifier(textField)]?(textField.text)
        }
        textField.keyUp.addHandler { [weak internalState] _, event in
            guard let internalState else { return }

            if event?.key == .enter {
                internalState.textFieldSubmitActions[ObjectIdentifier(textField)]?()
            }
        }
        return textField
    }

    public func updateTextField(
        _ textField: Widget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        let textField = textField as! TextBox
        textField.placeholderText = placeholder
        internalState.textFieldChangeActions[ObjectIdentifier(textField)] = onChange
        internalState.textFieldSubmitActions[ObjectIdentifier(textField)] = onSubmit
        environment.apply(to: textField)

        updateInputScope(of: textField, textContentType: environment.textContentType)
        applyTextFieldStyle(of: textField, style: environment.textFieldStyle)
    }

    public func setContent(ofTextField textField: Widget, to content: String) {
        (textField as! TextBox).text = content
    }

    public func getContent(ofTextField textField: Widget) -> String {
        (textField as! TextBox).text
    }
}

// MARK: SecureField

extension WinUIBackend {
    public func createSecureField() -> Widget {
        let secureField = PasswordBox()
        secureField.passwordChanged.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.textFieldChangeActions[ObjectIdentifier(secureField)]?(
                secureField.password
            )
        }
        secureField.keyUp.addHandler { [weak internalState] _, event in
            guard let internalState else { return }

            if event?.key == .enter {
                internalState.textFieldSubmitActions[ObjectIdentifier(secureField)]?()
            }
        }
        return secureField
    }

    public func updateSecureField(
        _ secureField: Widget,
        placeholder: String,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        let secureField = secureField as! PasswordBox
        secureField.placeholderText = placeholder
        internalState.textFieldChangeActions[ObjectIdentifier(secureField)] = onChange
        internalState.textFieldSubmitActions[ObjectIdentifier(secureField)] = onSubmit
        environment.apply(to: secureField)

        updateInputScope(of: secureField, textContentType: environment.textContentType)
        applyTextFieldStyle(of: secureField, style: environment.textFieldStyle)
    }

    public func setContent(ofSecureField secureField: Widget, to content: String) {
        (secureField as! PasswordBox).password = content
    }

    public func getContent(ofSecureField secureField: Widget) -> String {
        (secureField as! PasswordBox).password
    }
}

extension WinUIBackend {
    /// Applies the resolved ``TextFieldStyle`` to a WinUI text control.
    /// `.plain` removes the native border and background so the field reads
    /// as bare text on the window's background, like on macOS.
    func applyTextFieldStyle(of control: WinUI.Control, style: SwiftCrossUI.TextFieldStyle) {
        guard style == .plain else { return }
        applyPlainTextControlChrome(to: control)
    }

    /// Strips every visual that distinguishes a WinUI text control from plain
    /// text — resting border/background as well as the pointer-over and
    /// focused visual states (WinUI's TextBox template swaps in
    /// `TextControl*Focused` theme resources on focus, so overriding just the
    /// `borderThickness`/`background` properties leaves a visible chrome the
    /// moment the control gains focus).
    func applyPlainTextControlChrome(to control: WinUI.Control) {
        control.borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        let transparent = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        let brush = WinUI.SolidColorBrush()
        brush.color = transparent
        control.background = brush

        // Visual-state theme resources used by the TextBox/PasswordBox
        // template. Overriding them at the control level wins over the theme
        // dictionaries in resource lookup order. Resource values must be
        // objects XAML can repackage — a Swift `Thickness` inserted directly
        // boxes to an unidentifiable IInspectable and crashes the template
        // binding, so a genuine XAML-boxed thickness is extracted from a
        // throwaway control instead.
        for key in [
            "TextControlBackground",
            "TextControlBackgroundPointerOver",
            "TextControlBackgroundFocused",
            "TextControlBackgroundDisabled",
            "TextControlBorderBrush",
            "TextControlBorderBrushPointerOver",
            "TextControlBorderBrushFocused",
            "TextControlBorderBrushDisabled",
        ] {
            _ = control.resources.insert(key, brush)
        }
        for key in [
            "TextControlBorderThemeThickness",
            "TextControlBorderThemeThicknessFocused",
        ] {
            _ = control.resources.insert(key, boxedZeroThickness)
        }
    }
}

/// A zero `Thickness` boxed by XAML itself, suitable for insertion into a
/// `ResourceDictionary` — Swift-side struct boxing produces inspectables
/// that the template engine can't repackage.
private let boxedZeroThickness: Any? = {
    let box = WinUI.Border()
    box.borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)
    return try? box.getValue(WinUI.Border.borderThicknessProperty)
}()

// MARK: TextBoxProtocol

protocol TextBoxProtocol: Control {
    var inputScope: InputScope! { get set }
}

extension TextBox: TextBoxProtocol {}
extension PasswordBox: TextBoxProtocol {}
