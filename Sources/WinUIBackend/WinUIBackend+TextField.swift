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
        control.borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        let transparent = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        let background = WinUI.SolidColorBrush()
        background.color = transparent
        control.background = background
    }
}

// MARK: TextBoxProtocol

protocol TextBoxProtocol: Control {
    var inputScope: InputScope! { get set }
}

extension TextBox: TextBoxProtocol {}
extension PasswordBox: TextBoxProtocol {}
