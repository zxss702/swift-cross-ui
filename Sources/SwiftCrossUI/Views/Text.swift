import Foundation

/// A view the displays text.
///
/// ``Text`` truncates its content to fit within its proposed size. To wrap
/// without truncation, put the ``Text`` (or its enclosing view hierarchy) into
/// an ideal height context such as a ``ScrollView``. Alternatively, use
/// ``View/fixedSize(horizontal:vertical:)`` with `horizontal` set to false and
/// `vertical` set to true, but be aware that this may lead to unintuitive
/// minimum sizing behaviour when used within a window. Often when developers
/// use ``View/fixedSize()`` on text, what they really need is a ``ScrollView``.
///
/// To avoid wrapping and truncation entirely, use ``View/fixedSize()``.
///
/// ## Technical notes
///
/// The reason that ``Text`` truncates its content to fit its proposed size is
/// that SwiftCrossUI's layout system behaves rather unintuitively with views
/// that trade off width for height. The layout system used to support this
/// behaviour well, but when overhauling the layout system with performance in
/// mind, we discovered that it's not possible to handle minimum view sizing in
/// the intuitive way that we were, without a large performance cost or layout
/// system complexity cost.
///
/// With the current system, windows determine the minimum size of their content
/// by proposing a size of 0x0. A text view that doesn't truncate its content
/// would take on a width of 0 and then lay out each character on a new line (as
/// that's what most UI frameworks do when text is given a small width). This
/// leads to the window thinking that its minimum height is
/// `characterCount * lineHeight`, even though when given a width larger than
/// zero, the text view would be shorter than this 'minimum height'. The
/// underlying cause is the assumption that 'minimum size' is a sensible notion
/// for every view. A text view without truncation doesn't have a
/// 'minimum size'; are we minimizing width? height? width + height? area?
///
/// SwiftCrossUI's old layout system separated the concept of minimum size into
/// 'minimum width for current height', and 'minimum height for current width'.
/// This led to much more intuitive window sizing behaviour. If you had
/// non-truncating text inside a window, and resized the width of the window
/// such that the height of the text became taller than the window, then the
/// window would become taller, and if you resized the height of the window then
/// you'd reach the window's minimum height before the text could overflow the
/// window horizontally. Unfortunately this required a lot of book-keeping, and
/// was deemed to be unfeasible to do without significantly hurting performance
/// due to all the layout assumptions that we'd have to drop from our stack
/// layout algorithm.
///
/// The new layout system behaviour is in line with SwiftUI's layout behaviour.
public struct Text: Sendable, Equatable {
    /// The string to be shown in the text view.
    public private(set) var string: String

    /// An explicit font for the text, overriding the font from the
    /// environment. Used by text-level modifiers such as ``font(_:)``
    /// and ``bold()``.
    var storedFont: Font?

    /// An explicit foreground color for the text, overriding the color
    /// from the environment.
    var storedForegroundColor: Color?

    /// Whether the text is rendered struck through. `nil` inherits the
    /// environment's value.
    var isStrikethrough: Bool? = nil

    /// Whether the text is rendered underlined. `nil` inherits the
    /// environment's value.
    var isUnderline: Bool? = nil

    /// Creates a new text view that displays a string.
    ///
    /// - Parameter string: The string to display.
    public init(_ string: String) {
        self.string = string
    }

    /// Creates a new text view that displays a string-like value such as a
    /// `Substring`.
    ///
    /// - Parameter content: The string content to display.
    public init<S: StringProtocol>(_ content: S) {
        self.string = String(content)
    }

    /// Creates a new text view that displays an attributed string, as in
    /// SwiftUI.
    ///
    /// Attribute runs are currently flattened to plain text; rich run
    /// support is planned for a future release.
    public init(_ attributedContent: AttributedString) {
        self.string = String(attributedContent.characters)
    }

    /// Creates a text view that displays a value formatted by the given
    /// format style.
    ///
    /// - Parameters:
    ///   - input: The value to display.
    ///   - format: The format style used to convert the value to a string.
    public init<Input, F: FormatStyle>(
        _ input: Input,
        format: F
    ) where F.FormatInput == Input, F.FormatOutput == String {
        self.string = format.format(input)
    }

    /// Concatenates two text views. Styling attributes that don't fit in
    /// a single string's per-view environment (e.g. runs with different
    /// fonts) are collapsed to the left-hand side's attributes. Rich run
    /// support is planned for a future release.
    public static func + (lhs: Text, rhs: Text) -> Text {
        var result = Text(lhs.string + rhs.string)
        result.storedFont = lhs.storedFont ?? rhs.storedFont
        result.storedForegroundColor = lhs.storedForegroundColor ?? rhs.storedForegroundColor
        return result
    }

    /// Applies an explicit font to this text.
    public func font(_ font: Font) -> Text {
        var copy = self
        copy.storedFont = font
        return copy
    }

    /// Applies a font weight to this text.
    public func fontWeight(_ weight: Font.Weight?) -> Text {
        var copy = self
        copy.storedFont = (copy.storedFont ?? .body).weight(weight)
        return copy
    }

    /// Applies a font design to this text.
    public func fontDesign(_ design: Font.Design?) -> Text {
        var copy = self
        copy.storedFont = (copy.storedFont ?? .body).design(design)
        return copy
    }

    /// Applies a bold weight to this text.
    public func bold() -> Text {
        fontWeight(.bold)
    }

    /// Applies an italic style to this text.
    public func italic() -> Text {
        var copy = self
        copy.storedFont = (copy.storedFont ?? .body).italic()
        return copy
    }

    /// Applies a monospaced design to this text.
    public func monospaced() -> Text {
        fontDesign(.monospaced)
    }

    /// Applies a foreground color to this text.
    public func foregroundColor(_ color: Color) -> Text {
        var copy = self
        copy.storedForegroundColor = color
        return copy
    }

    /// Applies a strikethrough decoration to this text.
    public func strikethrough(_ active: Bool = true, color: Color? = nil) -> Text {
        var copy = self
        copy.isStrikethrough = active
        return copy
    }

    /// Applies an underline decoration to this text.
    public func underline(_ active: Bool = true, color: Color? = nil) -> Text {
        var copy = self
        copy.isUnderline = active
        return copy
    }

    /// Applies the stored styling attributes to the given environment.
    func environmentApplyingTextAttributes(to environment: EnvironmentValues) -> EnvironmentValues {
        var environment = environment
        if let storedFont {
            environment = environment.with(\.font, storedFont)
        }
        if let storedForegroundColor {
            environment = environment.with(\.foregroundColor, storedForegroundColor)
        }
        if let isStrikethrough {
            environment = environment.with(\.textStrikethrough, isStrikethrough)
        }
        if let isUnderline {
            environment = environment.with(\.textUnderline, isUnderline)
        }
        return environment
    }
}

extension Text: View {
    public var _asMenuItems: [MenuItem] {
        [.text(self)]
    }
}

extension Text: ElementaryView {
    public func asWidget<Backend: BaseAppBackend>(
        backend: Backend
    ) -> Backend.Widget {
        return backend.createTextView()
    }

    public func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let environment = environmentApplyingTextAttributes(to: environment)
        let transformedString = environment.applyingTextTransforms(to: string)

        // TODO: Avoid this. Move it to commit once we figure out a solution for Gtk.
        // Even in dry runs we must update the underlying text view widget
        // because GtkBackend currently relies on querying the widget for text
        // properties and such (via Pango).
        backend
            .updateTextView(widget, content: transformedString, environment: environment)

        // UI frameworks often handle the zero proposal specially. We want to
        // have standard text sizing behaviour so it's better for us to never
        // propose zero in either dimension and then fix up the resulting size
        // to match our expectations.
        //
        // Our desired behaviour is for a zero width proposal to result in at least
        // one line's worth of height (for a non-empty string). Furthermore, if
        // proposed more than one line's worth of height, then a zero width
        // proposal should result in height equivalent to however many lines are
        // required to put each character of the text on a new line (excluding
        // whitespace).
        //
        // A zero height proposal should result in the text using at least one
        // line of height (if non-empty).
        var size = backend.size(
            of: transformedString,
            whenDisplayedIn: widget,
            proposedWidth: proposedSize.width.flatMap {
                // For text, an infinite proposal is the same as an unspecified
                // proposal, and this works nicer with most backends than converting
                // .infinity to a large integer (which is the alternative).
                $0 == .infinity ? nil : $0
            }.map { LayoutSystem.roundSize($0) }.map { max(1, $0) },
            proposedHeight: proposedSize.height.flatMap {
                $0 == .infinity ? nil : $0
            }.map { LayoutSystem.roundSize($0) }.map { max(1, $0) },
            environment: environment
        )

        // If the proposed width was 0 and the resuling width was 1, then set the
        // resulting width to 0. See above for more detail.
        if proposedSize.width == 0 && size.x == 1 {
            size.x = 0
        }

        return ViewLayoutResult.leafView(size: ViewSize(size))
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setSize(of: widget, to: layout.size.vector)
    }
}
