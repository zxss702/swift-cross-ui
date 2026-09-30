// MARK: - Semantic Colors

extension Color {
    /// The primary foreground color, equivalent to the platform's default
    /// text color. Adapts to the current color scheme.
    ///
    /// Matches AppKit's `labelColor`.
    public static let primary = Color.adaptive(
        light: Color(white: 0.0).opacity(0.85),
        dark: Color(white: 1.0).opacity(0.85)
    )

    /// The secondary foreground color, used for less prominent text.
    ///
    /// Matches AppKit's `secondaryLabelColor`.
    public static let secondary = Color.adaptive(
        light: Color(white: 0.0).opacity(0.5),
        dark: Color(white: 1.0).opacity(0.55)
    )

    /// The tertiary foreground color, used for placeholder text and other
    /// low-prominence content.
    ///
    /// Matches AppKit's `tertiaryLabelColor`.
    public static let tertiary = Color.adaptive(
        light: Color(white: 0.0).opacity(0.26),
        dark: Color(white: 1.0).opacity(0.25)
    )

    /// The quaternary foreground color, used for the least prominent content.
    ///
    /// Matches AppKit's `quaternaryLabelColor`.
    public static let quaternary = Color.adaptive(
        light: Color(white: 0.0).opacity(0.1),
        dark: Color(white: 1.0).opacity(0.1)
    )

    /// The platform's accent color, used for interactive elements.
    ///
    /// Matches AppKit's `controlAccentColor` default (blue).
    public static let accentColor = Color.adaptive(
        light: Color(red: 0.0, green: 0.478, blue: 1.0),
        dark: Color(red: 0.039, green: 0.518, blue: 1.0)
    )
}
